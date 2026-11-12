/* Storage volume XML parser + formatter, against a fixed directory pool. */
#include "harness_common.h"
#include "conf/storage_conf.h"

static virStoragePoolDef *pool;

static const char poolXml[] =
    "<pool type='dir'>"
    "  <name>fuzzpool</name>"
    "  <uuid>c2c2cc40-3d01-4d3c-8b3b-2e6f6a1c5c11</uuid>"
    "  <capacity unit='bytes'>0</capacity>"
    "  <allocation unit='bytes'>0</allocation>"
    "  <available unit='bytes'>0</available>"
    "  <target><path>/var/lib/libvirt/images</path></target>"
    "</pool>";

int
LLVMFuzzerInitialize(int *argc G_GNUC_UNUSED, char ***argv G_GNUC_UNUSED)
{
    mayhem_quiet_init();
    pool = virStoragePoolDefParse(poolXml, NULL, 0);
    if (!pool)
        abort();
    return 0;
}

int
LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    char *xml = mayhem_nul_copy(data, size);
    virStorageVolDef *def = virStorageVolDefParse(pool, xml, NULL, 0);
    int rc = -1;

    if (def) {
        char *out = virStorageVolDefFormat(pool, def);
        free(out);
        virStorageVolDefFree(def);
        rc = 0;
    }
    free(xml);
    return rc;
}
