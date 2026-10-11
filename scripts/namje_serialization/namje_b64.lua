-- base64 + zlib/deflate (RFC 1950/1951) for ship content and ship codes, in pure Lua 5.3.
--
-- packed format: MAGIC .. base64(zlib(data))
-- MAGIC can't collide with anything written before compression was added:
--  - legacy ship codes are plain base64, and '~' is outside the base64 alphabet
--  - legacy ship content is raw binary starting with the material count (I2), and "~z" as an I2 is 31358,
--    far above the 1023 ids the material cache can hold

namje_b64 = {}
namje_b64.MAGIC = "~z1"

local byte, char, concat, unpack = string.byte, string.char, table.concat, table.unpack

--- converts a 1-indexed byte array into a string
local function bytes_to_string(bytes, count)
    local parts = {}
    for i = 1, count, 4096 do
        parts[#parts + 1] = char(unpack(bytes, i, math.min(i + 4095, count)))
    end
    return concat(parts)
end

-------------------------------------------------------------------------------
-- base64
-------------------------------------------------------------------------------

local BASE64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local ENCODE_MAP = {}   -- 6 bit value -> char
local DECODE_MAP = {}   -- char byte -> 6 bit value
local ENCODE_PAIRS = {} -- 12 bit value -> 2 chars
for i = 1, 64 do
    local c = BASE64_CHARS:sub(i, i)
    ENCODE_MAP[i - 1] = c
    DECODE_MAP[c:byte()] = i - 1
end
for i = 0, 4095 do
    ENCODE_PAIRS[i] = ENCODE_MAP[i >> 6] .. ENCODE_MAP[i & 63]
end

--- encodes a binary string to a base64 string
--- @param data string
--- @returns string
function namje_b64.encode(data)
    local len = #data
    local full = len - len % 3
    local result, k = {}, 0

    for i = 1, full, 3 do
        local b1, b2, b3 = byte(data, i, i + 2)
        local n = (b1 << 16) | (b2 << 8) | b3
        k = k + 1
        result[k] = ENCODE_PAIRS[n >> 12] .. ENCODE_PAIRS[n & 4095]
    end

    local rem = len - full
    if rem == 1 then
        local n = byte(data, len) << 16
        result[k + 1] = ENCODE_PAIRS[n >> 12] .. "=="
    elseif rem == 2 then
        local b1, b2 = byte(data, len - 1, len)
        local n = (b1 << 16) | (b2 << 8)
        result[k + 1] = ENCODE_PAIRS[n >> 12] .. ENCODE_MAP[(n >> 6) & 63] .. "="
    end

    return concat(result)
end

--- decodes a base64 string back to a binary string. whitespace and other non-base64 characters are ignored
--- @param b64_data string
--- @returns string
function namje_b64.decode(b64_data)
    local cleaned_data = b64_data:gsub("[^A-Za-z0-9%+/]", "")
    local len = #cleaned_data
    local full = len - len % 4
    local result, k = {}, 0

    for i = 1, full, 4 do
        local c1, c2, c3, c4 = byte(cleaned_data, i, i + 3)
        local n = (DECODE_MAP[c1] << 18) | (DECODE_MAP[c2] << 12) | (DECODE_MAP[c3] << 6) | DECODE_MAP[c4]
        k = k + 1
        result[k] = char(n >> 16, (n >> 8) & 255, n & 255)
    end

    local rem = len - full
    if rem == 1 then
        error("namje // invalid base64 data length")
    elseif rem > 1 then
        local c1, c2, c3 = byte(cleaned_data, full + 1, len)
        local n = (DECODE_MAP[c1] << 18) | (DECODE_MAP[c2] << 12) | ((c3 and DECODE_MAP[c3] or 0) << 6)
        result[k + 1] = rem == 2 and char(n >> 16) or char(n >> 16, (n >> 8) & 255)
    end

    return concat(result)
end

-------------------------------------------------------------------------------
-- deflate tables (index = code + 1)
-------------------------------------------------------------------------------

local LEN_BASE = {3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258}
local LEN_EXTRA = {0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0}
local DIST_BASE = {1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577}
local DIST_EXTRA = {0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13}
local CODE_LENGTH_ORDER = {16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15}

local MAX_BITS = 15
local WINDOW_SIZE = 32768
local MIN_MATCH = 3
local MAX_MATCH = 258
-- compression effort. higher chain = smaller output but slower saves
local MAX_CHAIN = 64
local NICE_MATCH = 128
local BLOCK_TOKENS = 16384

local function fixed_lengths()
    local lit, dist = {}, {}
    for i = 0, 143 do lit[i] = 8 end
    for i = 144, 255 do lit[i] = 9 end
    for i = 256, 279 do lit[i] = 7 end
    for i = 280, 287 do lit[i] = 8 end
    for i = 0, 29 do dist[i] = 5 end
    return lit, dist
end

-------------------------------------------------------------------------------
-- deflate (compression)
-------------------------------------------------------------------------------

local len_code_lookup, dist_code_lookup
local fixed_lit_codes, fixed_lit_lens, fixed_dist_codes, fixed_dist_lens

local function reverse_bits(code, len)
    local r = 0
    for _ = 1, len do
        r = (r << 1) | (code & 1)
        code = code >> 1
    end
    return r
end

--- canonical huffman codes from code lengths, bit-reversed since deflate writes them LSB first
local function make_codes(lengths, nsym)
    local bl_count = {}
    for i = 0, MAX_BITS do bl_count[i] = 0 end
    for s = 0, nsym - 1 do
        local l = lengths[s]
        if l > 0 then bl_count[l] = bl_count[l] + 1 end
    end
    local next_code, code = {}, 0
    for bits = 1, MAX_BITS do
        code = (code + bl_count[bits - 1]) << 1
        next_code[bits] = code
    end
    local codes = {}
    for s = 0, nsym - 1 do
        local l = lengths[s]
        if l > 0 then
            codes[s] = reverse_bits(next_code[l], l)
            next_code[l] = next_code[l] + 1
        else
            codes[s] = 0
        end
    end
    return codes
end

--- huffman code lengths for the given frequencies, limited to max_len bits.
--- always returns a complete code with at least two symbols, which every inflater accepts
local function build_lengths(freqs, nsym, max_len)
    local lengths, f, syms = {}, {}, {}
    for s = 0, nsym - 1 do
        lengths[s] = 0
        f[s] = freqs[s] or 0
        if f[s] > 0 then syms[#syms + 1] = s end
    end
    -- pad to two symbols so the code is complete
    for s = 0, nsym - 1 do
        if #syms >= 2 then break end
        if f[s] == 0 then
            f[s] = 1
            syms[#syms + 1] = s
        end
    end

    local m = #syms
    while true do
        table.sort(syms, function(a, b)
            if f[a] ~= f[b] then return f[a] < f[b] end
            return a < b
        end)

        -- two queue huffman: leaves 1..m (sorted), internal nodes m+1.. (created in nondecreasing weight order)
        local weight, parent = {}, {}
        for i = 1, m do weight[i] = f[syms[i]] end
        local leaf, node, next_node = 1, m + 1, m + 1
        local function pop()
            if leaf <= m and (node >= next_node or weight[leaf] <= weight[node]) then
                leaf = leaf + 1
                return leaf - 1
            end
            node = node + 1
            return node - 1
        end
        for _ = 1, m - 1 do
            local a, b = pop(), pop()
            weight[next_node] = weight[a] + weight[b]
            parent[a], parent[b] = next_node, next_node
            next_node = next_node + 1
        end

        local root = next_node - 1
        local depth = {[root] = 0}
        for i = root - 1, 1, -1 do
            depth[i] = depth[parent[i]] + 1
        end
        local max_depth = 0
        for i = 1, m do
            if depth[i] > max_depth then max_depth = depth[i] end
        end

        if max_depth <= max_len then
            for i = 1, m do lengths[syms[i]] = depth[i] end
            return lengths
        end
        -- too deep, flatten the distribution and retry
        for i = 1, m do
            local s = syms[i]
            f[s] = math.max(1, f[s] >> 1)
        end
    end
end

local function init_encoder_tables()
    if len_code_lookup then return end
    len_code_lookup, dist_code_lookup = {}, {}
    for c = 0, 28 do
        for l = LEN_BASE[c + 1], LEN_BASE[c + 1] + (1 << LEN_EXTRA[c + 1]) - 1 do
            len_code_lookup[l] = c
        end
    end
    -- 258 has its own code (28), which overrides the end of code 27's range above
    for c = 0, 29 do
        for d = DIST_BASE[c + 1], DIST_BASE[c + 1] + (1 << DIST_EXTRA[c + 1]) - 1 do
            dist_code_lookup[d] = c
        end
    end
    fixed_lit_lens, fixed_dist_lens = fixed_lengths()
    fixed_lit_codes = make_codes(fixed_lit_lens, 288)
    fixed_dist_codes = make_codes(fixed_dist_lens, 30)
end

--- LZ77 pass. returns parallel token arrays: symbol (literal byte or 257+ length code), match length, match distance
local function lz77(data)
    local n = #data
    local b = {}
    for i = 1, n, 4096 do
        local chunk = {byte(data, i, math.min(i + 4095, n))}
        for j = 1, #chunk do b[i + j - 1] = chunk[j] end
    end

    local head, prev = {}, {}
    local tok_sym, tok_len, tok_dist, tok_count = {}, {}, {}, 0

    local function insert(p)
        local key = (b[p] << 16) | (b[p + 1] << 8) | b[p + 2]
        prev[p] = head[key]
        head[key] = p
    end

    local function longest_match(p)
        local candidate = head[(b[p] << 16) | (b[p + 1] << 8) | b[p + 2]]
        local best_len, best_dist = 0, 0
        local max_len = math.min(MAX_MATCH, n - p + 1)
        local chain = MAX_CHAIN
        while candidate and chain > 0 do
            local dist = p - candidate
            if dist > WINDOW_SIZE then break end
            -- the hash key is the exact 3 bytes, so every candidate already matches MIN_MATCH bytes
            if b[candidate + best_len] == b[p + best_len] then
                local l = MIN_MATCH
                while l < max_len and b[candidate + l] == b[p + l] do l = l + 1 end
                if l > best_len then
                    best_len, best_dist = l, dist
                    if l >= NICE_MATCH or l == max_len then break end
                end
            end
            candidate = prev[candidate]
            chain = chain - 1
        end
        return best_len, best_dist
    end

    local function emit_literal(v)
        tok_count = tok_count + 1
        tok_sym[tok_count], tok_len[tok_count], tok_dist[tok_count] = v, 0, 0
    end

    local function emit_match(len, dist)
        tok_count = tok_count + 1
        tok_sym[tok_count], tok_len[tok_count], tok_dist[tok_count] = 257 + len_code_lookup[len], len, dist
    end

    -- lazy matching: a match is only taken if the next position doesn't have a longer one
    local i = 1
    local pending, pending_len, pending_dist = false, 0, 0
    while i <= n do
        local cur_len, cur_dist = 0, 0
        if i + 2 <= n then
            cur_len, cur_dist = longest_match(i)
            insert(i)
        end

        if pending then
            if cur_len > pending_len then
                emit_literal(b[i - 1])
                pending_len, pending_dist = cur_len, cur_dist
                i = i + 1
            else
                emit_match(pending_len, pending_dist)
                local match_end = i - 1 + pending_len
                for p = i + 1, math.min(match_end - 1, n - 2) do insert(p) end
                pending = false
                i = match_end
            end
        elseif cur_len >= MIN_MATCH then
            pending, pending_len, pending_dist = true, cur_len, cur_dist
            i = i + 1
        else
            emit_literal(b[i])
            i = i + 1
        end
    end
    if pending then emit_match(pending_len, pending_dist) end

    return tok_sym, tok_len, tok_dist, tok_count
end

--- compresses a binary string into a zlib stream
--- @param data string
--- @returns string
function namje_b64.compress(data)
    init_encoder_tables()

    local out, out_count = {}, 0
    local bit_buf, bit_count = 0, 0
    local function put(value, nbits)
        bit_buf = bit_buf | (value << bit_count)
        bit_count = bit_count + nbits
        while bit_count >= 8 do
            out_count = out_count + 1
            out[out_count] = bit_buf & 255
            bit_buf = bit_buf >> 8
            bit_count = bit_count - 8
        end
    end

    -- zlib header: deflate, 32k window, max compression
    out[1], out[2], out_count = 0x78, 0xDA, 2

    local tok_sym, tok_len, tok_dist, tok_count = lz77(data)

    local block_start = 1
    repeat
        local block_end = math.min(block_start + BLOCK_TOKENS - 1, tok_count)
        local is_final = block_end == tok_count

        local lit_freq, dist_freq = {}, {}
        for s = 0, 285 do lit_freq[s] = 0 end
        for s = 0, 29 do dist_freq[s] = 0 end
        lit_freq[256] = 1
        for t = block_start, block_end do
            local s = tok_sym[t]
            lit_freq[s] = lit_freq[s] + 1
            if s > 256 then
                local dc = dist_code_lookup[tok_dist[t]]
                dist_freq[dc] = dist_freq[dc] + 1
            end
        end

        local lit_lens = build_lengths(lit_freq, 286, MAX_BITS)
        local dist_lens = build_lengths(dist_freq, 30, MAX_BITS)

        local hlit, hdist = 286, 30
        while hlit > 257 and lit_lens[hlit - 1] == 0 do hlit = hlit - 1 end
        while hdist > 1 and dist_lens[hdist - 1] == 0 do hdist = hdist - 1 end

        -- run length encode the code lengths with symbols 16 (repeat previous), 17/18 (repeat zero)
        local all_lens = {}
        for s = 0, hlit - 1 do all_lens[#all_lens + 1] = lit_lens[s] end
        for s = 0, hdist - 1 do all_lens[#all_lens + 1] = dist_lens[s] end

        local cl_sym, cl_extra, cl_count = {}, {}, 0
        local cl_freq = {}
        for s = 0, 18 do cl_freq[s] = 0 end
        local function cl_emit(sym, extra)
            cl_count = cl_count + 1
            cl_sym[cl_count], cl_extra[cl_count] = sym, extra
            cl_freq[sym] = cl_freq[sym] + 1
        end

        local idx = 1
        while idx <= #all_lens do
            local l = all_lens[idx]
            local run = 1
            while idx + run <= #all_lens and all_lens[idx + run] == l do run = run + 1 end
            idx = idx + run
            if l == 0 then
                while run >= 11 do
                    local r = math.min(run, 138)
                    cl_emit(18, r - 11)
                    run = run - r
                end
                if run >= 3 then
                    cl_emit(17, run - 3)
                    run = 0
                end
            else
                cl_emit(l, 0)
                run = run - 1
                while run >= 3 do
                    local r = math.min(run, 6)
                    cl_emit(16, r - 3)
                    run = run - r
                end
            end
            for _ = 1, run do cl_emit(l, 0) end
        end

        local cl_lens = build_lengths(cl_freq, 19, 7)
        local hclen = 19
        while hclen > 4 and cl_lens[CODE_LENGTH_ORDER[hclen]] == 0 do hclen = hclen - 1 end

        -- pick whichever of dynamic/fixed huffman is smaller. extra bits are the same for both, so they're skipped
        local CL_EXTRA_BITS = {[16] = 2, [17] = 3, [18] = 7}
        local dynamic_bits = 14 + 3 * hclen
        for c = 1, cl_count do
            dynamic_bits = dynamic_bits + cl_lens[cl_sym[c]] + (CL_EXTRA_BITS[cl_sym[c]] or 0)
        end
        local fixed_bits = 0
        for s = 0, 285 do
            dynamic_bits = dynamic_bits + lit_freq[s] * lit_lens[s]
            fixed_bits = fixed_bits + lit_freq[s] * fixed_lit_lens[s]
        end
        for s = 0, 29 do
            dynamic_bits = dynamic_bits + dist_freq[s] * dist_lens[s]
            fixed_bits = fixed_bits + dist_freq[s] * 5
        end

        local lit_codes, dist_codes
        put(is_final and 1 or 0, 1)
        if dynamic_bits < fixed_bits then
            put(2, 2)
            put(hlit - 257, 5)
            put(hdist - 1, 5)
            put(hclen - 4, 4)
            for c = 1, hclen do put(cl_lens[CODE_LENGTH_ORDER[c]], 3) end
            local cl_codes = make_codes(cl_lens, 19)
            for c = 1, cl_count do
                local s = cl_sym[c]
                put(cl_codes[s], cl_lens[s])
                if s >= 16 then put(cl_extra[c], CL_EXTRA_BITS[s]) end
            end
            lit_codes, dist_codes = make_codes(lit_lens, 286), make_codes(dist_lens, 30)
        else
            put(1, 2)
            lit_codes, lit_lens, dist_codes, dist_lens = fixed_lit_codes, fixed_lit_lens, fixed_dist_codes, fixed_dist_lens
        end

        for t = block_start, block_end do
            local s = tok_sym[t]
            put(lit_codes[s], lit_lens[s])
            if s > 256 then
                local lc = s - 257
                if LEN_EXTRA[lc + 1] > 0 then put(tok_len[t] - LEN_BASE[lc + 1], LEN_EXTRA[lc + 1]) end
                local d = tok_dist[t]
                local dc = dist_code_lookup[d]
                put(dist_codes[dc], dist_lens[dc])
                if DIST_EXTRA[dc + 1] > 0 then put(d - DIST_BASE[dc + 1], DIST_EXTRA[dc + 1]) end
            end
        end
        put(lit_codes[256], lit_lens[256])

        block_start = block_end + 1
    until is_final

    if bit_count > 0 then put(0, 8 - bit_count) end

    local adler = namje_b64.adler32(data)
    for shift = 24, 0, -8 do
        out_count = out_count + 1
        out[out_count] = (adler >> shift) & 255
    end

    return bytes_to_string(out, out_count)
end

-------------------------------------------------------------------------------
-- inflate (decompression)
-------------------------------------------------------------------------------

local fixed_lit_decoder, fixed_dist_decoder

local function build_decoder(lengths, nsym)
    local count, symbol, offs = {}, {}, {}
    for l = 0, MAX_BITS do count[l] = 0 end
    for s = 0, nsym - 1 do count[lengths[s]] = count[lengths[s]] + 1 end
    local left = 1
    for l = 1, MAX_BITS do
        left = (left << 1) - count[l]
        if left < 0 then error("namje // invalid compressed data (oversubscribed huffman code)") end
    end
    offs[1] = 0
    for l = 1, MAX_BITS - 1 do offs[l + 1] = offs[l] + count[l] end
    for s = 0, nsym - 1 do
        local l = lengths[s]
        if l ~= 0 then
            symbol[offs[l]] = s
            offs[l] = offs[l] + 1
        end
    end
    return {count = count, symbol = symbol}
end

--- inflates a raw deflate stream starting at pos. returns the decompressed string and the position after the stream
local function inflate_raw(data, pos)
    local data_len = #data
    local bit_buf, bit_count = 0, 0
    local out, out_count = {}, 0

    local function bits(n)
        while bit_count < n do
            if pos > data_len then error("namje // compressed data is truncated") end
            bit_buf = bit_buf | (byte(data, pos) << bit_count)
            pos = pos + 1
            bit_count = bit_count + 8
        end
        local v = bit_buf & ((1 << n) - 1)
        bit_buf = bit_buf >> n
        bit_count = bit_count - n
        return v
    end

    local function decode(h)
        local count, symbol = h.count, h.symbol
        local code, first, index = 0, 0, 0
        for l = 1, MAX_BITS do
            code = code | bits(1)
            local c = count[l]
            if code - c < first then return symbol[index + code - first] end
            index = index + c
            first = (first + c) << 1
            code = code << 1
        end
        error("namje // invalid compressed data (bad huffman code)")
    end

    local function inflate_codes(lit, dist)
        while true do
            local sym = decode(lit)
            if sym < 256 then
                out_count = out_count + 1
                out[out_count] = sym
            elseif sym == 256 then
                return
            else
                sym = sym - 257
                if sym >= 29 then error("namje // invalid compressed data (bad length code)") end
                local length = LEN_BASE[sym + 1] + bits(LEN_EXTRA[sym + 1])
                local dsym = decode(dist)
                if dsym >= 30 then error("namje // invalid compressed data (bad distance code)") end
                local d = DIST_BASE[dsym + 1] + bits(DIST_EXTRA[dsym + 1])
                if d > out_count then error("namje // invalid compressed data (distance too far back)") end
                local from = out_count - d
                for k = 1, length do
                    out[out_count + k] = out[from + k]
                end
                out_count = out_count + length
            end
        end
    end

    repeat
        local final = bits(1)
        local block_type = bits(2)
        if block_type == 0 then
            -- stored block: skip to the byte boundary (bit_count is always < 8 here)
            bit_buf, bit_count = 0, 0
            if pos + 3 > data_len then error("namje // compressed data is truncated") end
            local l1, l2, n1, n2 = byte(data, pos, pos + 3)
            pos = pos + 4
            local len = l1 | (l2 << 8)
            if len ~= (~(n1 | (n2 << 8)) & 0xFFFF) then error("namje // invalid compressed data (stored block length)") end
            if pos + len - 1 > data_len then error("namje // compressed data is truncated") end
            for i = pos, pos + len - 1 do
                out_count = out_count + 1
                out[out_count] = byte(data, i)
            end
            pos = pos + len
        elseif block_type == 1 then
            if not fixed_lit_decoder then
                local lit, dist = fixed_lengths()
                fixed_lit_decoder, fixed_dist_decoder = build_decoder(lit, 288), build_decoder(dist, 30)
            end
            inflate_codes(fixed_lit_decoder, fixed_dist_decoder)
        elseif block_type == 2 then
            local nlen = bits(5) + 257
            local ndist = bits(5) + 1
            local ncode = bits(4) + 4
            if nlen > 286 or ndist > 30 then error("namje // invalid compressed data (bad code counts)") end

            local cl_lens = {}
            for s = 0, 18 do cl_lens[s] = 0 end
            for c = 1, ncode do cl_lens[CODE_LENGTH_ORDER[c]] = bits(3) end
            local cl_decoder = build_decoder(cl_lens, 19)

            local lengths, idx = {}, 0
            while idx < nlen + ndist do
                local sym = decode(cl_decoder)
                if sym < 16 then
                    lengths[idx] = sym
                    idx = idx + 1
                else
                    local l, rep = 0, 0
                    if sym == 16 then
                        if idx == 0 then error("namje // invalid compressed data (repeat with no length)") end
                        l, rep = lengths[idx - 1], 3 + bits(2)
                    elseif sym == 17 then
                        rep = 3 + bits(3)
                    else
                        rep = 11 + bits(7)
                    end
                    if idx + rep > nlen + ndist then error("namje // invalid compressed data (too many lengths)") end
                    for _ = 1, rep do
                        lengths[idx] = l
                        idx = idx + 1
                    end
                end
            end
            if lengths[256] == 0 then error("namje // invalid compressed data (missing end of block code)") end

            local lit_lens, dist_lens = {}, {}
            for s = 0, nlen - 1 do lit_lens[s] = lengths[s] end
            for s = 0, ndist - 1 do dist_lens[s] = lengths[nlen + s] end
            inflate_codes(build_decoder(lit_lens, nlen), build_decoder(dist_lens, ndist))
        else
            error("namje // invalid compressed data (bad block type)")
        end
    until final == 1

    return bytes_to_string(out, out_count), pos
end

--- decompresses a zlib stream, verifying its checksum
--- @param data string
--- @returns string
function namje_b64.decompress(data)
    if #data < 6 then error("namje // compressed data is truncated") end
    local cmf, flg = byte(data, 1, 2)
    if cmf & 0x0F ~= 8 or ((cmf << 8) | flg) % 31 ~= 0 or flg & 0x20 ~= 0 then
        error("namje // data is not a zlib stream")
    end

    local result, pos = inflate_raw(data, 3)

    if pos + 3 > #data then error("namje // compressed data is truncated") end
    local a1, a2, a3, a4 = byte(data, pos, pos + 3)
    if ((a1 << 24) | (a2 << 16) | (a3 << 8) | a4) ~= namje_b64.adler32(result) then
        error("namje // compressed data is corrupted (checksum mismatch)")
    end
    return result
end

--- @param data string
--- @returns number
function namje_b64.adler32(data)
    -- 64 bit integers can't overflow here for any realistic size, so the modulo is only taken per chunk
    local a, b = 1, 0
    local len = #data
    for i = 1, len, 4096 do
        local chunk = {byte(data, i, math.min(i + 4095, len))}
        for j = 1, #chunk do
            a = a + chunk[j]
            b = b + a
        end
        a = a % 65521
        b = b % 65521
    end
    return (b << 16) | a
end

-------------------------------------------------------------------------------
-- packed (compressed + base64) strings
-------------------------------------------------------------------------------

--- compresses and base64 encodes a binary string, prefixed with namje_b64.MAGIC
--- @param data string
--- @returns string
function namje_b64.pack(data)
    return namje_b64.MAGIC .. namje_b64.encode(namje_b64.compress(data))
end

--- whether the string was produced by namje_b64.pack. anything else is legacy (uncompressed) data
--- @param str string
--- @returns boolean
function namje_b64.is_packed(str)
    return type(str) == "string" and str:sub(1, #namje_b64.MAGIC) == namje_b64.MAGIC
end

--- reverses namje_b64.pack. errors if the data is corrupted or wasn't packed
--- @param str string
--- @returns string
function namje_b64.unpack(str)
    if not namje_b64.is_packed(str) then
        error("namje // data is not packed")
    end
    return namje_b64.decompress(namje_b64.decode(str:sub(#namje_b64.MAGIC + 1)))
end
