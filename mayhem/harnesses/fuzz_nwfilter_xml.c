/* Network filter XML parser + formatter. */
#include "harness_common.h"
#include "conf/nwfilter_conf.h"

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
    virNWFilterDef *def = virNWFilterDefParse(xml, NULL, 0);
    int rc = -1;

    if (def) {
        char *out = virNWFilterDefFormat(def);
        free(out);
        virNWFilterDefFree(def);
        rc = 0;
    }
    free(xml);
    return rc;
}
