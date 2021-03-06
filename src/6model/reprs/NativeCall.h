#ifndef NATIVECALL_H_GUARD
#define NATIVECALL_H_GUARD

#include "dyncall/dyncall.h"
#include "dynload/dynload.h"

/* Body of a NativeCall. */
typedef struct {
    char *lib_name;
    void *lib_handle;
    void *entry_point;
    INTVAL convention;
    INTVAL num_args;
    INTVAL *arg_types;
    INTVAL ret_type;
} NativeCallBody;

/* This is how an instance with the NativeCall representation looks. */
typedef struct {
    SixModelObjectCommonalities common;
    NativeCallBody body;
} NativeCallInstance;

/* Initializes the NativeCall REPR. */
REPROps * NativeCall_initialize(PARROT_INTERP,
        PMC * (* wrap_object_func_ptr) (PARROT_INTERP, void *obj),
        PMC * (* create_stable_func_ptr) (PARROT_INTERP, REPROps *REPR, PMC *HOW));

#endif
