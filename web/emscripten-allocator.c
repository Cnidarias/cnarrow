#include <stdint.h>
#include <stdlib.h>
#include <string.h>

void *cnarrow_aligned_alloc(size_t size, size_t alignment) {
    size_t header = sizeof(void *);
    uintptr_t mask = (uintptr_t)alignment - 1;
    void *base = malloc(size + alignment + header);
    if (base == NULL) return NULL;
    uintptr_t aligned = ((uintptr_t)base + header + mask) & ~mask;
    ((void **)aligned)[-1] = base;
    memset((void *)aligned, 0, size);
    return (void *)aligned;
}

void cnarrow_aligned_free(void *ptr) {
    if (ptr == NULL) return;
    free(((void **)ptr)[-1]);
}
