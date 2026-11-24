module cabi.kitty;

import std.experimental.allocator.mallocator : Mallocator;
import clipboard : Metadata, ParseError;

extern (C):

int velocitty_clipboard_op(const(ubyte)* raw, size_t len, int* op)
{
    Metadata md;
    const err = Metadata.parse(Mallocator.instance, raw[0 .. len], md);

    if (err == ParseError.none)
    {
        *op = md.op;
        md.free(Mallocator.instance);
    }

    return err;
}