module cabi.allocator;

import core.stdc.stdlib : free, malloc;
import std.experimental.allocator.common : platformAlignment;

alias VelocittyAllocFn = extern (C) void* function(void* ctx, size_t len);
alias VelocittyFreeFn = extern (C) void function(void* ctx, void* ptr, size_t len);

struct VelocittyAllocator {
    void* ctx;
    VelocittyAllocFn alloc;
    VelocittyFreeFn free;
}

package struct CAllocator {
    VelocittyAllocator c;
    enum uint alignment = platformAlignment;

    void[] allocate(size_t n) {
        if (n == 0)
            return null;

        void* p = c.alloc ? c.alloc(c.ctx, n) : malloc(n);
        return p ? p[0 .. n] : null;
    }

    bool deallocate(void[] b) {
        if (b.ptr is null)
            return true;

        if (c.free)
            c.free(c.ctx, b.ptr, b.length);
        else
            free(b.ptr);
        return true;
    }
}

package CAllocator from(const(VelocittyAllocator)* a) {
    return a ? CAllocator(cast(VelocittyAllocator) *a) : CAllocator.init;
}

extern (C):

void velocitty_free(const(VelocittyAllocator)* allocator, ubyte* ptr, size_t len) {
    from(allocator).deallocate(ptr[0 .. len]);
}