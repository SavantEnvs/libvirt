/* Secret XML parser + formatter. */
#include "harness_common.h"
#include "conf/secret_conf.h"

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
    virSecretDef *def = virSecretDefParse(xml, NULL, 0);
    int rc = -1;

    if (def) {
        char *out = virSecretDefFormat(def);
        free(out);
        virSecretDefFree(def);
        rc = 0;
    }
    free(xml);
    return rc;
}
