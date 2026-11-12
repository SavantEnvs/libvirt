/* Domain XML parser + formatter (generic hypervisor-neutral xmlopt). */
#include "harness_common.h"
#include "conf/domain_conf.h"

static virDomainXMLOption *xmlopt;

static virDomainDefParserConfig parserConfig = {
    .features = VIR_DOMAIN_DEF_FEATURE_INDIVIDUAL_VCPUS,
};

int
LLVMFuzzerInitialize(int *argc G_GNUC_UNUSED, char ***argv G_GNUC_UNUSED)
{
    mayhem_quiet_init();
    xmlopt = virDomainXMLOptionNew(&parserConfig, NULL, NULL, NULL, NULL, NULL);
    if (!xmlopt)
        abort();
    return 0;
}

int
LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    char *xml = mayhem_nul_copy(data, size);
    virDomainDef *def = virDomainDefParseString(xml, xmlopt, NULL, 0);
    int rc = -1;

    if (def) {
        char *out = virDomainDefFormat(def, xmlopt, VIR_DOMAIN_DEF_FORMAT_SECURE);
        free(out);
        virDomainDefFree(def);
        rc = 0;
    }
    free(xml);
    return rc;
}
