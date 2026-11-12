/* Virtual network XML parser + formatter. */
#include "harness_common.h"
#include "conf/network_conf.h"

static virNetworkXMLOption *xmlopt;

int
LLVMFuzzerInitialize(int *argc G_GNUC_UNUSED, char ***argv G_GNUC_UNUSED)
{
    mayhem_quiet_init();
    xmlopt = virNetworkXMLOptionNew(NULL);
    if (!xmlopt)
        abort();
    return 0;
}

int
LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    char *xml = mayhem_nul_copy(data, size);
    virNetworkDef *def = virNetworkDefParse(xml, NULL, xmlopt, false);
    int rc = -1;

    if (def) {
        char *out = virNetworkDefFormat(def, xmlopt, 0);
        free(out);
        virNetworkDefFree(def);
        rc = 0;
    }
    free(xml);
    return rc;
}
