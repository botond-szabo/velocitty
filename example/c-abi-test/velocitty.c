#include <stdio.h>
#include <string.h>
#include "velocitty.h"

int main(void) {
    VelocittyTerminal terminal;
    velocitty_terminal_new(NULL, &terminal, 80, 24);

    const char *text = "Hello, \x1b[1;32mworld\x1b[0m!\r";
    velocitty_terminal_vt_write(terminal, (const uint8_t *)text, strlen(text));

    VelocittyFormatter formatter;
    velocitty_formatter_terminal_new(NULL, &formatter, terminal);
    
    uint8_t *buf = NULL;
    uint64_t len = 0;
    velocitty_formatter_format_alloc(formatter, NULL, &buf, &len);
    fwrite(buf, 1, len, stdout);
    putchar('\n');
    
    velocitty_free(NULL, buf, len);
    velocitty_formatter_free(formatter);
    velocitty_terminal_free(terminal);
}