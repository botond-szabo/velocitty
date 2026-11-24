module terminal;

import core.stdc.string : memmove;
import std.algorithm : min;
import std.experimental.allocator : dispose, makeArray;

struct Cell
{
    dchar codepoint = ' ';
}

private enum State : ubyte
{
    ground,
    escape,
    csi,
}

/// Minimal screen: a fixed grid plus a cursor. Escape sequences are
/// recognised and skipped (no colors or cursor movement yet).
struct Terminal
{
    ushort cols, rows;
    ushort cursorX, cursorY;
    Cell[] cells;
    private State state;

    bool initialize(A)(ref A alloc, ushort cols, ushort rows)
    {
        cells = alloc.makeArray!Cell(cols * rows);
        if (cells is null)
            return false;

        this.cols = cols;
        this.rows = rows;
        return true;
    }

    void release(A)(ref A alloc)
    {
        alloc.dispose(cells);
        cells = null;
    }

    bool resize(A)(ref A alloc, ushort newCols, ushort newRows)
    {
        auto fresh = alloc.makeArray!Cell(newCols * newRows);
        if (fresh is null)
            return false;

        foreach (y; 0 .. min(rows, newRows))
            foreach (x; 0 .. min(cols, newCols))
                fresh[y * newCols + x] = cells[y * cols + x];

        alloc.dispose(cells);
        cells = fresh;
        cols = newCols;
        rows = newRows;
        cursorX = min(cursorX, cast(ushort)(cols - 1));
        cursorY = min(cursorY, cast(ushort)(rows - 1));
        return true;
    }

    ref Cell cell(ushort x, ushort y)
    {
        return cells[y * cols + x];
    }

    void feed(const(ubyte)[] data)
    {
        foreach (b; data)
        {
            // Skip escape sequences until the parser exists.
            if (state == State.escape)
            {
                state = b == '[' ? State.csi : State.ground;
                continue;
            }
            if (state == State.csi)
            {
                if (b >= 0x40 && b <= 0x7e)
                    state = State.ground;
                continue;
            }

            switch (b)
            {
            case 0x1b:
                state = State.escape;
                break;

            case '\r':
                cursorX = 0;
                break;

            case '\n':
                lineFeed();
                break;

            case '\b':
                if (cursorX > 0)
                    cursorX--;
                break;

            default:
                // Other control bytes are ignored until the parser exists.
                if (b < 0x20 || b == 0x7f)
                    break;

                if (cursorX == cols)
                {
                    cursorX = 0;
                    lineFeed();
                }

                cell(cursorX, cursorY).codepoint = b;
                cursorX++;
            }
        }
    }

    /// Writes the screen as plain text: rows joined by '\n', trailing spaces
    /// and trailing blank rows dropped. Pass null to get the length only.
    size_t formatPlain(char[] dst) const
    {
        size_t last = rows;
        while (last > 0 && rowEnd(cast(ushort)(last - 1)) == 0)
            last--;

        size_t n;
        foreach (y; 0 .. last)
        {
            foreach (x; 0 .. rowEnd(cast(ushort) y))
            {
                const cp = cells[y * cols + x].codepoint;
                if (dst.length)
                    dst[n] = cp < 128 ? cast(char) cp : '?';
                n++;
            }
            if (y + 1 < last)
            {
                if (dst.length)
                    dst[n] = '\n';
                n++;
            }
        }
        return n;
    }

    private size_t rowEnd(ushort y) const
    {
        size_t end = cols;
        while (end > 0 && cells[y * cols + end - 1].codepoint == ' ')
            end--;
        return end;
    }

    private void lineFeed()
    {
        if (cursorY + 1 < rows)
        {
            cursorY++;
            return;
        }

        // Bottom row: scroll everything up one line.
        memmove(cells.ptr, cells.ptr + cols, (cells.length - cols) * Cell.sizeof);
        cells[$ - cols .. $] = Cell.init;
    }
}

unittest
{
    import std.experimental.allocator.mallocator : Mallocator;
    import std.string : representation;

    Terminal t;
    assert(t.initialize(Mallocator.instance, 5, 2));
    scope (exit)
        t.release(Mallocator.instance);

    t.feed("ab\r\ncd\r\nef".representation);
    assert(t.cell(0, 0).codepoint == 'c'); // first line scrolled off
    assert(t.cell(0, 1).codepoint == 'e');
}

unittest
{
    import std.experimental.allocator.mallocator : Mallocator;
    import std.string : representation;

    Terminal t;
    assert(t.initialize(Mallocator.instance, 20, 3));
    scope (exit)
        t.release(Mallocator.instance);

    t.feed("Hello, \x1b[1;32mworld\x1b[0m!\r\n".representation);

    char[64] buf;
    const n = t.formatPlain(buf[]);
    assert(n == t.formatPlain(null));
    assert(buf[0 .. n] == "Hello, world!");
}