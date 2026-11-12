/* Shared plumbing for the libvirt libFuzzer harnesses (bytes in, no file I/O). */
#pragma once

#include <config.h>

#include <stdlib.h>
#include <string.h>

#include "internal.h"
#include "virerror.h"
#include "virlog.h"

static void
mayhem_ignore_error(void *opaque G_GNUC_UNUSED,
                    virErrorPtr err G_GNUC_UNUSED)
{
}

/* Parse errors are the expected outcome for most inputs; keep them off stderr. */
static void
mayhem_quiet_init(void)
{
    virErrorInitialize();
    virSetErrorFunc(NULL, mayhem_ignore_error);
    virLogSetOutputs("4:file:/dev/null");
}

/* NUL-terminated private copy of the fuzzer's buffer. */
static char *
mayhem_nul_copy(const uint8_t *data, size_t size)
{
    char *buf = malloc(size + 1);

    if (!buf)
        abort();
    memcpy(buf, data, size);
    buf[size] = '\0';
    return buf;
}
