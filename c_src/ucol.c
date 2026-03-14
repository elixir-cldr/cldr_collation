/*
 * This file is part of ucol_nif released under the MIT license.
 * See the NOTICE for more information.
 */

#ifdef DARWIN
#define U_HIDE_DRAFT_API 1
#define U_DISABLE_RENAMING 1
#endif

#include "erl_nif.h"
#include "unicode/ucol.h"
#include "unicode/ucasemap.h"
#include "unicode/uscript.h"
#include <stdio.h>
#include <assert.h>

static ERL_NIF_TERM ATOM_TRUE;
static ERL_NIF_TERM ATOM_FALSE;
static ERL_NIF_TERM ATOM_NULL;

typedef struct {
    ErlNifEnv* env;
    int error;
    UCollator* coll;
} ctx_t;

typedef struct {
    UCollator** collators;
    int collStackTop;
    int numCollators;
    ErlNifMutex* collMutex;
} priv_data_t;

/* Use -1 as sentinel for "use default / no change" */
#define OPT_DEFAULT (-1)

static ERL_NIF_TERM ucol(ErlNifEnv*, int, const ERL_NIF_TERM []);
static int on_load(ErlNifEnv*, void**, ERL_NIF_TERM);
static void on_unload(ErlNifEnv*, void*);
static __inline void reserve_coll(priv_data_t*, ctx_t*);
static __inline void release_coll(priv_data_t*, ctx_t*);
int on_reload(ErlNifEnv*, void**, ERL_NIF_TERM);
int on_upgrade(ErlNifEnv*, void**, void**, ERL_NIF_TERM);

void
reserve_coll(priv_data_t* pData, ctx_t *ctx)
{
    if (ctx->coll == NULL) {
        enif_mutex_lock(pData->collMutex);
        assert(pData->collStackTop < pData->numCollators);
        ctx->coll = pData->collators[pData->collStackTop];
        pData->collStackTop += 1;
        enif_mutex_unlock(pData->collMutex);
    }
}


void
release_coll(priv_data_t* pData, ctx_t *ctx)
{
    if (ctx->coll != NULL) {
        enif_mutex_lock(pData->collMutex);
        pData->collStackTop -= 1;
        assert(pData->collStackTop >= 0);
        enif_mutex_unlock(pData->collMutex);
    }
}

/* ------------------------------------------------------------------------- */

/*
 * cmp(string_a, string_b, strength, backwards, alternate, case_first,
 *     case_level, normalization, numeric, reorder_bin)
 *
 * Each option is an integer. OPT_DEFAULT (-1) means "use collator default".
 * Other values are the ICU enum values (e.g. UCOL_PRIMARY=0, UCOL_ON=17).
 *
 * reorder_bin is a binary of packed big-endian int32 reorder codes.
 * Empty binary means no reordering. Non-empty triggers ucol_setReorderCodes().
 */
static ERL_NIF_TERM
ucol(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    ErlNifBinary binA, binB, reorderBin;
    int strength, backwards, alternate, case_first, case_level, normalization, numeric;
    int any_set = 0;
    int has_reorder = 0;
    ctx_t ctx;
    priv_data_t* pData;
    UErrorCode status = U_ZERO_ERROR;
    UCharIterator iterA, iterB;
    int response;

    ctx.env = env;
    ctx.error = 0;
    ctx.coll = NULL;

    pData = (priv_data_t*) enif_priv_data(env);

    /* Extract binary arguments */
    if (!enif_inspect_binary(env, argv[0], &binA) ||
        !enif_inspect_binary(env, argv[1], &binB)) {
        return enif_make_int(env, 0);
    }

    /* Extract option integers */
    if (!enif_get_int(env, argv[2], &strength) ||
        !enif_get_int(env, argv[3], &backwards) ||
        !enif_get_int(env, argv[4], &alternate) ||
        !enif_get_int(env, argv[5], &case_first) ||
        !enif_get_int(env, argv[6], &case_level) ||
        !enif_get_int(env, argv[7], &normalization) ||
        !enif_get_int(env, argv[8], &numeric)) {
        return enif_make_int(env, 0);
    }

    /* Extract reorder codes binary (10th arg) */
    if (!enif_inspect_binary(env, argv[9], &reorderBin)) {
        return enif_make_int(env, 0);
    }

    /* Set up UTF-8 iterators */
    uiter_setUTF8(&iterA, (const char *) binA.data, (uint32_t) binA.size);
    uiter_setUTF8(&iterB, (const char *) binB.data, (uint32_t) binB.size);

    /* Grab a collator from the pool */
    reserve_coll(pData, &ctx);

    /* Apply non-default attributes */
    if (strength != OPT_DEFAULT) {
        ucol_setAttribute(ctx.coll, UCOL_STRENGTH, (UColAttributeValue) strength, &status);
        any_set = 1;
    }
    if (backwards != OPT_DEFAULT) {
        ucol_setAttribute(ctx.coll, UCOL_FRENCH_COLLATION, (UColAttributeValue) backwards, &status);
        any_set = 1;
    }
    if (alternate != OPT_DEFAULT) {
        ucol_setAttribute(ctx.coll, UCOL_ALTERNATE_HANDLING, (UColAttributeValue) alternate, &status);
        any_set = 1;
    }
    if (case_first != OPT_DEFAULT) {
        ucol_setAttribute(ctx.coll, UCOL_CASE_FIRST, (UColAttributeValue) case_first, &status);
        any_set = 1;
    }
    if (case_level != OPT_DEFAULT) {
        ucol_setAttribute(ctx.coll, UCOL_CASE_LEVEL, (UColAttributeValue) case_level, &status);
        any_set = 1;
    }
    if (normalization != OPT_DEFAULT) {
        ucol_setAttribute(ctx.coll, UCOL_NORMALIZATION_MODE, (UColAttributeValue) normalization, &status);
        any_set = 1;
    }
    if (numeric != OPT_DEFAULT) {
        ucol_setAttribute(ctx.coll, UCOL_NUMERIC_COLLATION, (UColAttributeValue) numeric, &status);
        any_set = 1;
    }

    /* Apply reorder codes if provided */
    if (reorderBin.size > 0 && reorderBin.size % 4 == 0) {
        int32_t numCodes = (int32_t)(reorderBin.size / 4);
        int32_t* codes = (int32_t*) enif_alloc(sizeof(int32_t) * numCodes);
        int32_t i;
        const unsigned char* p = reorderBin.data;

        for (i = 0; i < numCodes; i++) {
            /* Decode big-endian int32 */
            codes[i] = (int32_t)(
                ((uint32_t)p[0] << 24) |
                ((uint32_t)p[1] << 16) |
                ((uint32_t)p[2] << 8)  |
                ((uint32_t)p[3])
            );
            p += 4;
        }

        ucol_setReorderCodes(ctx.coll, codes, numCodes, &status);
        enif_free(codes);
        has_reorder = 1;
    }

    /* Perform the comparison */
    response = ucol_strcollIter(ctx.coll, &iterA, &iterB, &status);

    /* Restore all modified attributes to defaults */
    if (any_set) {
        status = U_ZERO_ERROR;
        if (strength != OPT_DEFAULT)
            ucol_setAttribute(ctx.coll, UCOL_STRENGTH, UCOL_DEFAULT, &status);
        if (backwards != OPT_DEFAULT)
            ucol_setAttribute(ctx.coll, UCOL_FRENCH_COLLATION, UCOL_DEFAULT, &status);
        if (alternate != OPT_DEFAULT)
            ucol_setAttribute(ctx.coll, UCOL_ALTERNATE_HANDLING, UCOL_DEFAULT, &status);
        if (case_first != OPT_DEFAULT)
            ucol_setAttribute(ctx.coll, UCOL_CASE_FIRST, UCOL_DEFAULT, &status);
        if (case_level != OPT_DEFAULT)
            ucol_setAttribute(ctx.coll, UCOL_CASE_LEVEL, UCOL_DEFAULT, &status);
        if (normalization != OPT_DEFAULT)
            ucol_setAttribute(ctx.coll, UCOL_NORMALIZATION_MODE, UCOL_DEFAULT, &status);
        if (numeric != OPT_DEFAULT)
            ucol_setAttribute(ctx.coll, UCOL_NUMERIC_COLLATION, UCOL_DEFAULT, &status);
    }

    /* Restore reorder codes to default */
    if (has_reorder) {
        int32_t defaultCode = UCOL_REORDER_CODE_DEFAULT;
        status = U_ZERO_ERROR;
        ucol_setReorderCodes(ctx.coll, &defaultCode, 1, &status);
    }

    release_coll(pData, &ctx);

    return enif_make_int(env, response);
}

/* ------------------------------------------------------------------------- */

int
on_load(ErlNifEnv* env, void** priv_data, ERL_NIF_TERM info)
{
    UErrorCode status = U_ZERO_ERROR;
    priv_data_t* pData = (priv_data_t*)enif_alloc(sizeof(priv_data_t));
    int i, j;

    /* Initialize the structure */
    pData->collators = NULL;
    pData->collStackTop = 0;
    pData->numCollators = 0;
    pData->collMutex = NULL;

    if (!enif_get_int(env, info, &(pData->numCollators) )) {
        enif_free((char*)pData);
        return 1;
    }

    if (pData->numCollators < 1) {
        enif_free((char*)pData);
        return 2;
    }

    pData->collMutex = enif_mutex_create((char *)"coll_mutex");

    if (pData->collMutex == NULL) {
        enif_free((char*)pData);
        return 3;
    }

    pData->collators = enif_alloc(sizeof(UCollator*) * pData->numCollators);

    if (pData->collators == NULL) {
        enif_mutex_destroy(pData->collMutex);
        enif_free((char*)pData);
        return 4;
    }

    for (i = 0; i < pData->numCollators; i++) {
        pData->collators[i] = ucol_open("", &status);

        if (U_FAILURE(status)) {
            for (j = 0; j < i; j++) {
                ucol_close(pData->collators[j]);
            }

            enif_free(pData->collators);
            enif_mutex_destroy(pData->collMutex);

            enif_free((char*)pData);

            return 5;
        }
    }

    ATOM_TRUE = enif_make_atom(env, "true");
    ATOM_FALSE = enif_make_atom(env, "false");
    ATOM_NULL = enif_make_atom(env, "null");

    *priv_data = pData;

    return 0;
}


void
on_unload(ErlNifEnv* env, void* priv_data)
{
    priv_data_t* pData = (priv_data_t*)priv_data;
    if (pData->collators != NULL) {
        int i;

        for (i = 0; i < pData->numCollators; i++) {
            ucol_close(pData->collators[i]);
        }

        enif_free(pData->collators);
    }

    if (pData->collMutex != NULL) {
        enif_mutex_destroy(pData->collMutex);
    }

    enif_free((char*)pData);
}

int
on_reload(ErlNifEnv* env, void** priv_data, ERL_NIF_TERM info)
{
    return 0;
}

int
on_upgrade(ErlNifEnv* env, void** priv_data, void** old_data, ERL_NIF_TERM info)
{
    if (*old_data != NULL) {
        priv_data_t* pData = (priv_data_t*)old_data;

        if (pData->collators != NULL) {
            int i;

            for (i = 0; i < pData->numCollators; i++) {
                ucol_close(pData->collators[i]);
            }

            enif_free(pData->collators);
        }

        if (pData->collMutex != NULL) {
            enif_mutex_destroy(pData->collMutex);
        }

        enif_free((char*)pData);
    }

    return on_load(env, priv_data, info);
}

/* ------------------------------------------------------------------------- */

static ErlNifFunc
nif_funcs[] =
{
    {"cmp", 10, ucol}
};

ERL_NIF_INIT(Elixir.Cldr.Collation.Nif, nif_funcs, &on_load, &on_reload, &on_upgrade, &on_unload)
