/* Node device XML parser + formatter. */
#include "harness_common.h"
#include "conf/node_device_conf.h"

int
LLVMFuzzerInitialize(int *argc G_GNUC_UNUSED, char ***argv G_GNUC_UNUSED)
{
    mayhem_quiet_init();
    return 0;
}

int
LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    char *xml = mayhem_nul_copy(data, size);
    virNodeDeviceDef *def = virNodeDeviceDefParse(xml, NULL, 0, NULL, NULL, NULL, false);
    int rc = -1;

    if (def) {
        char *out = virNodeDeviceDefFormat(def, 0);
        free(out);
        virNodeDeviceDefFree(def);
        rc = 0;
    }
    free(xml);
    return rc;
}
