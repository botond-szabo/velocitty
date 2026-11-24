module cabi.common;

enum VelocittyResult : int
{
    success = 0,
    outOfMemory = 1,
    invalidValue = 2,
}

extern (C):

int velocitty_version()
{
    return 1;
}