#include <string.h>
#include <assert.h>

void uinttostring(uint32_t nb, char* str, uint8_t base)
{
    assert(str != NULL);

    uint32_t quotient;
    uint32_t remaining;
    uint8_t nbdigits = 0;

    do {
        quotient = nb / base;
        remaining = nb % base;

        remaining += '0';
        if (remaining > '9') {
            remaining += 7;
        }
        str[nbdigits] = remaining;
        ++nbdigits;

        nb = quotient;
    } while (quotient != 0);

    strnrev(str, nbdigits);
    str[nbdigits] = '\0';
}

void inttostring(int32_t nb, char* str, uint8_t base)
{
    assert(str != NULL);

    if (nb < 0) {
        str[0] = '-';
        ++str;
        nb = -nb;
    }

    uinttostring(nb, str, base);
}