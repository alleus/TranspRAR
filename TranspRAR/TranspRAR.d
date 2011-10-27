#!/usr/sbin/dtrace -s

#pragma D option quiet

macfuse_objc*:::delegate-entry
/execname == "TranspRAR"/
{
    printf("%-14d %s: %s\n", timestamp, probefunc, copyinstr(arg0));
}
