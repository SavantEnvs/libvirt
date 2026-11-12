/* Disk image header probing + metadata extraction (qcow2, qed, vmdk, luks, ...). */
#include "harness_common.h"
#include "storage_file/storage_file_probe.h"
#include "storage_source_conf.h"

int
LLVMFuzzerInitialize(int *argc G_GNUC_UNUSED, char ***argv G_GNUC_UNUSED)
{
    mayhem_quiet_init();
    return 0;
}

int
LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    char *buf = mayhem_nul_copy(data, size);
    virStorageSource *meta = virStorageSourceNew();
    int rc = -1;

    meta->format = VIR_STORAGE_FILE_AUTO;
    if (virStorageFileProbeGetMetadata(meta, buf, size) == 0)
        rc = 0;
    virObjectUnref(meta);
    free(buf);
    return rc;
}
