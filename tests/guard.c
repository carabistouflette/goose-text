// SPDX-License-Identifier: Apache-2.0
// Linux-only development test: inaccessible pages detect native slice overreads.
#define _GNU_SOURCE
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
#include "parser-fuzz.h"
static uint8_t *guard_base;
static size_t guard_size;
static void check(uint8_t *data, size_t size, int64_t expected) {
    if (mprotect(guard_base, guard_size, PROT_READ)) { perror("mprotect read-only"); exit(1); }
    int64_t got = fuzz_parse((sl_u8){data, (int64_t)size});
    if (mprotect(guard_base, guard_size, PROT_READ | PROT_WRITE)) { perror("mprotect writable"); exit(1); }
    if (got != expected) {
        fprintf(stderr, "guard mismatch: length=%zu expected=%lld got=%lld\n",
                size, (long long)expected, (long long)got);
        exit(1);
    }
}
int main(int argc, char **argv) {
    long page = sysconf(_SC_PAGESIZE);
    if (page < 512) { fputs("unsupported page size\n", stderr); return 1; }
    uint8_t *mapping = mmap(NULL, (size_t)page * 3, PROT_NONE,
                            MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (mapping == MAP_FAILED) { perror("mmap"); return 1; }
    uint8_t *base = mapping + page;
    if (mprotect(base, (size_t)page, PROT_READ | PROT_WRITE)) { perror("mprotect"); return 1; }
    guard_base = base; guard_size = (size_t)page;
    goose_init(argc, argv);
    check(NULL, 0, -1);
    // At the left edge any underread faults; at the right edge any overread faults.
    for (int edge = 0; edge < 2; ++edge) {
        for (size_t size = 0; size <= 256; ++size) {
            uint8_t *data = edge ? base + page - size : base;
            memset(data, 'a', size);
            check(data, size, -1);
            for (size_t at = 0; at < size; ++at) {
                data[at] = 0xff;
                check(data, size, (int64_t)at);
                data[at] = 'a';
            }
            static const uint8_t scalars[][4] = {
                {0xc2, 0x80}, {0xdf, 0xbf}, {0xe0, 0xa0, 0x80},
                {0xed, 0x9f, 0xbf}, {0xf0, 0x90, 0x80, 0x80}, {0xf4, 0x8f, 0xbf, 0xbf}
            };
            static const size_t widths[] = {2, 2, 3, 3, 4, 4};
            for (size_t seq = 0; seq < sizeof(widths) / sizeof(widths[0]); ++seq) {
                for (size_t bytes = 1; bytes <= widths[seq] && bytes <= size; ++bytes) {
                    memset(data, 'a', size);
                    memcpy(data + size - bytes, scalars[seq], bytes);
                    check(data, size, bytes == widths[seq] ? -1 : (int64_t)(size - bytes));
                }
            }
        }
    }
    goose_exit();
    if (munmap(mapping, (size_t)page * 3)) { perror("munmap"); return 1; }
    puts("Native guard-page UTF-8 checks passed");
    return 0;
}
