module clipboard;

import std.algorithm : countUntil, splitter;
import std.experimental.allocator : dispose, makeArray;

static const int MAX_ID_LENGTH = 512;

static const int MAX_PW_LENGTH = 128;

static const int MAX_MIME_LENGTH = 256;

static const int MAX_NAME_LENGTH = 256;

enum Location {
    standard,
    primary,
}

enum Operation {
    read,
    write,
}

enum ParseError {
    none,
    missingOp,
    unknownOp,
    overflow,
    invalidBase64,
    invalidUtf8,
    outOfMem,
}

struct Metadata {
    Operation op;

    Location loc = Location.standard;

    const(ubyte)[] id, mime, pw, name;

    static ParseError parse(A)(ref A alloc, const(ubyte)[] raw, out Metadata result) {
        const(ubyte)[] op, loc, id, mime, pw, name;
        bool hasOp;

        foreach (field; raw.splitter(':')) {
            const eq = field.countUntil('=');

            if (eq < 0)
                continue;

            const value = field[eq + 1 .. $];

            switch (cast(const(char)[]) field[0 .. eq]) {
                case "type":
                    op = value;
                    hasOp = true;
                    break;

                case "loc":
                    loc = value;
                    break;

                case "id":
                    id = value;
                    break;

                case "mime":
                    mime = value;
                    break;

                case "pw":
                    pw = value;
                    break;

                case "name":
                    name = value;
                    break;

                default:
                    break;
            }
        }

        if (!hasOp)
            return ParseError.missingOp;

        switch (cast(const(char)[]) op) {
            case "read":
                result.op = Operation.read;
                break;

            case "write":
                result.op = Operation.write;
                break;

            default:
                return ParseError.unknownOp;
        }

        result.loc = cast(const(char)[]) loc == "primary" ? Location.primary : Location.standard;

        ParseError err;

        if ((err = sanitizeId(alloc, id, result.id)) != ParseError.none ||
            (err = decodeValue(alloc, mime, MAX_MIME_LENGTH, result.mime)) != ParseError.none ||
             // Over-long password = no password: overflow doesn't stop the chain.
            ((err = decodeValue(alloc, pw, MAX_PW_LENGTH, result.pw)) != ParseError.none && err != ParseError.overflow) ||
            (err = decodeValue(alloc, name, MAX_NAME_LENGTH, result.name)) != ParseError.none
            )
        {
            result.free(alloc);
            return err;
        }

        return ParseError.none;
    }

    void free(A)(ref A alloc) {
        alloc.dispose(cast(ubyte[]) id);
        id = null;

        alloc.dispose(cast(ubyte[]) mime);
        mime = null;

        alloc.dispose(cast(ubyte[]) pw);
        pw = null;

        alloc.dispose(cast(ubyte[]) name);
        name = null;
    }
}

private ParseError sanitizeId(A)(ref A alloc, const(ubyte)[] raw, out const(ubyte)[] result) {
    if (raw.length > MAX_ID_LENGTH)
        raw = raw[0 .. MAX_ID_LENGTH];

    size_t n;
    foreach (c; raw)
        if (isIdChar(c))
            n++;

    if (n == 0)
        return ParseError.none;

    auto buf = alloc.makeArray!ubyte(n);
    if (buf is null)
        return ParseError.outOfMem;

    size_t i;
    foreach (c; raw)
        if (isIdChar(c))
            buf[i++] = c;

    result = buf;
    return ParseError.none;
}

private bool isIdChar(ubyte c) @nogc nothrow pure {
    import std.ascii : isAlphaNum;

    return isAlphaNum(c) || c == '-' || c == '_' || c == '.';
}

private ParseError decodeValue(A)(ref A alloc, const(ubyte)[] b64, size_t max, out const(ubyte)[] result) {
    if (b64.length == 0)
        return ParseError.none;

    if (b64.length % 4)
        return ParseError.invalidBase64;

    size_t len = b64.length / 4 * 3;
    if (b64[$ - 1] == '=')
        len--;
    if (b64[$ - 2] == '=')
        len--;

    if (len > max)
        return ParseError.overflow;

    auto buf = alloc.makeArray!ubyte(len);
    if (buf is null)
        return ParseError.outOfMem;

    const err = !base64Decode(b64, buf) ? ParseError.invalidBase64
              : !isValidUtf8(buf)       ? ParseError.invalidUtf8
              : ParseError.none;

    if (err)
        alloc.dispose(buf);
    else
        result = buf;

    return err;
}

private bool base64Decode(const(ubyte)[] src, ubyte[] dst) @nogc nothrow pure {
    size_t o;
    for (size_t i = 0; i < src.length; i += 4) {
        uint v;
        int pad;

        foreach (j; 0 .. 4) {
            const c = src[i + j];
            int d = c >= 'A' && c <= 'Z' ? c - 'A'
                  : c >= 'a' && c <= 'z' ? c - 'a' + 26
                  : c >= '0' && c <= '9' ? c - '0' + 52
                  : c == '+' ? 62 : c == '/' ? 63 : -1;

            if (c == '=' && j >= 2 && i + 4 == src.length) {
                pad++;
                d = 0;
            } else if (d < 0 || pad) {
                return false;
            }

            v = v << 6 | d;
        }

        foreach (j; 0 .. 3 - pad)
            dst[o++] = cast(ubyte)(v >> (16 - 8 * j));
    }

    return true;
}

private bool isValidUtf8(const(ubyte)[] s) @nogc nothrow pure {
    import std.typecons : Yes;
    import std.utf : decode, replacementDchar;

    auto str = cast(const(char)[]) s;
    for (size_t i = 0; i < str.length;) {
        const start = i;

        if (decode!(Yes.useReplacementDchar)(str, i) == replacementDchar && str[start .. i] != "�")
            return false;
    }

    return true;
}

version (unittest)
{
    import std.experimental.allocator.mallocator : Mallocator;
    import std.string : representation;

    private ParseError parseStr(string s, out Metadata md)
    {
        return Metadata.parse(Mallocator.instance, s.representation, md);
    }
}

unittest
{
    Metadata md;
    assert(parseStr("type=read:loc=primary:mime=dGV4dC9wbGFpbg==", md) == ParseError.none);
    scope (exit)
        md.free(Mallocator.instance);

    assert(md.op == Operation.read);
    assert(md.loc == Location.primary);
    assert(md.mime == "text/plain".representation);
}

unittest
{
    Metadata md;
    assert(parseStr("mime=dGV4dA==", md) == ParseError.missingOp);
    assert(parseStr("type=copy", md) == ParseError.unknownOp);
    assert(parseStr("type=read:mime=!!!!", md) == ParseError.invalidBase64);
}

unittest
{
    import std.array : replicate;

    // A password over MAX_PW_LENGTH is dropped, not an error.
    Metadata md;
    assert(parseStr("type=read:pw=" ~ "QUFB".replicate(44), md) == ParseError.none);
    scope (exit)
        md.free(Mallocator.instance);
    assert(md.pw.length == 0);
}