/* libvirt's JSON parser/serializer (also the QEMU monitor/agent wire format). */
#include "harness_common.h"
#include "virjson.h"

int
LLVMFuzzerInitialize(int *argc G_GNUC_UNUSED, char ***argv G_GNUC_UNUSED)
{
    mayhem_quiet_init();
    return 0;
}

int
LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    char *json = mayhem_nul_copy(data, size);
    virJSONValue *val = virJSONValueFromString(json);
    int rc = -1;

    if (val) {
        char *out = virJSONValueToString(val, false);
        free(out);
        out = virJSONValueToString(val, true);
        free(out);
        virJSONValueFree(val);
        rc = 0;
    }
    free(json);
    return rc;
}
