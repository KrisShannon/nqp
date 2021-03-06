#define PARROT_IN_EXTENSION
#include "parrot/parrot.h"
#include "parrot/extend.h"
#include "../sixmodelobject.h"
#include "CStruct.h"

/* This representation's function pointer table. */
static REPROps *this_repr;

/* Some functions we have to get references to. */
static PMC * (* wrap_object_func) (PARROT_INTERP, void *obj);
static PMC * (* create_stable_func) (PARROT_INTERP, REPROps *REPR, PMC *HOW);

/* How do we go from type-object to a hash value? For now, we make an integer
 * that is the address of the STable struct, which not being subject to GC will
 * never move, and is unique per type object too. */
#define CLASS_KEY(c) ((INTVAL)PMC_data(STABLE_PMC(c)))

/* Helper to make an introspection call, possibly with :local. */
static PMC * introspection_call(PARROT_INTERP, PMC *WHAT, PMC *HOW, STRING *name, INTVAL local) {
    PMC *old_ctx, *cappy;
    
    /* Look up method; if there is none hand back a null. */
    PMC *meth = VTABLE_find_method(interp, HOW, name);
    if (PMC_IS_NULL(meth))
        return meth;

    /* Set up call capture. */
    old_ctx = Parrot_pcc_get_signature(interp, CURRENT_CONTEXT(interp));
    cappy   = Parrot_pmc_new(interp, enum_class_CallContext);
    VTABLE_push_pmc(interp, cappy, HOW);
    VTABLE_push_pmc(interp, cappy, WHAT);
    if (local)
        VTABLE_set_integer_keyed_str(interp, cappy, Parrot_str_new_constant(interp, "local"), 1);

    /* Call. */
    Parrot_pcc_invoke_from_sig_object(interp, meth, cappy);

    /* Grab result. */
    cappy = Parrot_pcc_get_signature(interp, CURRENT_CONTEXT(interp));
    Parrot_pcc_set_signature(interp, CURRENT_CONTEXT(interp), old_ctx);
    return VTABLE_get_pmc_keyed_int(interp, cappy, 0);
}

/* Helper to make an accessor call. */
static PMC * accessor_call(PARROT_INTERP, PMC *obj, STRING *name) {
    PMC *old_ctx, *cappy;
    
    /* Look up method; if there is none hand back a null. */
    PMC *meth = VTABLE_find_method(interp, obj, name);
    if (PMC_IS_NULL(meth))
        return meth;

    /* Set up call capture. */
    old_ctx = Parrot_pcc_get_signature(interp, CURRENT_CONTEXT(interp));
    cappy   = Parrot_pmc_new(interp, enum_class_CallContext);
    VTABLE_push_pmc(interp, cappy, obj);

    /* Call. */
    Parrot_pcc_invoke_from_sig_object(interp, meth, cappy);

    /* Grab result. */
    cappy = Parrot_pcc_get_signature(interp, CURRENT_CONTEXT(interp));
    Parrot_pcc_set_signature(interp, CURRENT_CONTEXT(interp), old_ctx);
    return VTABLE_get_pmc_keyed_int(interp, cappy, 0);
}

/* Locates all of the attributes. Puts them onto a flattened, ordered
 * list of attributes (populating the passed flat_list). Also builds
 * the index mapping for doing named lookups. Note index is not related
 * to the storage position. */
static PMC * index_mapping_and_flat_list(PARROT_INTERP, PMC *WHAT, CStructREPRData *repr_data) {
    PMC    *flat_list      = Parrot_pmc_new(interp, enum_class_ResizablePMCArray);
    PMC    *class_list     = Parrot_pmc_new(interp, enum_class_ResizablePMCArray);
    PMC    *attr_map_list  = Parrot_pmc_new(interp, enum_class_ResizablePMCArray);
    STRING *attributes_str = Parrot_str_new_constant(interp, "attributes");
    STRING *parents_str    = Parrot_str_new_constant(interp, "parents");
    STRING *name_str       = Parrot_str_new_constant(interp, "name");
    STRING *mro_str        = Parrot_str_new_constant(interp, "mro");
    INTVAL  current_slot   = 0;
    
    INTVAL num_classes, i;
    CStructNameMap * result = NULL;
    
    /* Get the MRO. */
    PMC   *mro     = introspection_call(interp, WHAT, STABLE(WHAT)->HOW, mro_str, 0);
    INTVAL mro_idx = VTABLE_elements(interp, mro);

    /* Walk through the parents list. */
    while (mro_idx)
    {
        /* Get current class in MRO. */
        PMC    *current_class = decontainerize(interp, VTABLE_get_pmc_keyed_int(interp, mro, --mro_idx));
        PMC    *HOW           = STABLE(current_class)->HOW;
        
        /* Get its local parents; make sure we're not doing MI. */
        PMC    *parents     = introspection_call(interp, current_class, HOW, parents_str, 1);
        INTVAL  num_parents = VTABLE_elements(interp, parents);
        if (num_parents <= 1) {
            /* Get attributes and iterate over them. */
            PMC *attributes = introspection_call(interp, current_class, HOW, attributes_str, 1);
            PMC *attr_map   = PMCNULL;
            PMC *attr_iter  = VTABLE_get_iter(interp, attributes);
            while (VTABLE_get_bool(interp, attr_iter)) {
                /* Get attribute. */
                PMC * attr = VTABLE_shift_pmc(interp, attr_iter);

                /* Get its name. */
                PMC    *name_pmc = accessor_call(interp, attr, name_str);
                STRING *name     = VTABLE_get_string(interp, name_pmc);

                /* Allocate a slot. */
                if (PMC_IS_NULL(attr_map))
                    attr_map = Parrot_pmc_new(interp, enum_class_Hash);
                VTABLE_set_pmc_keyed_str(interp, attr_map, name,
                    Parrot_pmc_new_init_int(interp, enum_class_Integer, current_slot));
                current_slot++;

                /* Push attr onto the flat list. */
                VTABLE_push_pmc(interp, flat_list, attr);
            }

            /* Add to class list and map list. */
            VTABLE_push_pmc(interp, class_list, current_class);
            VTABLE_push_pmc(interp, attr_map_list, attr_map);
        }
        else {
            Parrot_ex_throw_from_c_args(interp, NULL, EXCEPTION_INVALID_OPERATION,
                "CStruct representation does not support multiple inheritance");
        }
    }

    /* We can now form the name map. */
    num_classes = VTABLE_elements(interp, class_list);
    result = (CStructNameMap *) mem_sys_allocate_zeroed(sizeof(CStructNameMap) * (1 + num_classes));
    for (i = 0; i < num_classes; i++) {
        result[i].class_key = VTABLE_get_pmc_keyed_int(interp, class_list, i);
        result[i].name_map  = VTABLE_get_pmc_keyed_int(interp, attr_map_list, i);
    }
    repr_data->name_to_index_mapping = result;

    return flat_list;
}

/* This works out an allocation strategy for the object. It takes care of
 * "inlining" storage of attributes that are natively typed, as well as
 * noting unbox targets. */
static void compute_allocation_strategy(PARROT_INTERP, PMC *WHAT, CStructREPRData *repr_data) {
    STRING *type_str = Parrot_str_new_constant(interp, "type");
    PMC    *flat_list;

    /*
     * We have to block GC mark here. Because "repr" is assotiated with some
     * PMC which is not accessible in this function. And we have to write
     * barrier this PMC because we are poking inside it guts directly. We
     * do have WB in caller function, but it can be triggered too late is
     * any of allocation will cause GC run.
     *
     * This is kind of minor evil until after I'll find better solution.
     */
    Parrot_block_GC_mark(interp);

    /* Compute index mapping table and get flat list of attributes. */
    flat_list = index_mapping_and_flat_list(interp, WHAT, repr_data);
    
    /* If we have no attributes in the index mapping, then just the header. */
    if (repr_data->name_to_index_mapping[0].class_key == NULL) {
        repr_data->struct_size = 1; /* avoid 0-byte malloc */
    }

    /* Otherwise, we need to compute the allocation strategy.  */
    else {
        /* We track the size of the struct, which is what we'll want offsets into. */
        INTVAL cur_size = 0;
        
        /* Get number of attributes and set up various counters. */
        INTVAL num_attrs        = VTABLE_elements(interp, flat_list);
        INTVAL info_alloc       = num_attrs == 0 ? 1 : num_attrs;
        INTVAL cur_obj_attr     = 0;
        INTVAL cur_str_attr     = 0;
        INTVAL cur_init_slot    = 0;
        INTVAL i;

        /* Allocate location/offset arrays and GC mark info arrays. */
        repr_data->num_attributes      = num_attrs;
        repr_data->attribute_locations = (INTVAL *) mem_sys_allocate(info_alloc * sizeof(INTVAL));
        repr_data->struct_offsets      = (INTVAL *) mem_sys_allocate(info_alloc * sizeof(INTVAL));
        repr_data->flattened_stables   = (STable **) mem_sys_allocate_zeroed(info_alloc * sizeof(PMC *));

        /* Go over the attributes and arrange their allocation. */
        for (i = 0; i < num_attrs; i++) {
            /* Fetch its type; see if it's some kind of unboxed type. */
            PMC    *attr         = VTABLE_get_pmc_keyed_int(interp, flat_list, i);
            PMC    *type         = accessor_call(interp, attr, type_str);
            INTVAL  bits         = sizeof(void *) * 8;
            if (!PMC_IS_NULL(type)) {
                /* See if it's a type that we know how to handle in a C struct. */
                storage_spec spec = REPR(type)->get_storage_spec(interp, STABLE(type));
                if (spec.inlineable == STORAGE_SPEC_INLINED &&
                        (spec.boxed_primitive == STORAGE_SPEC_BP_INT ||
                         spec.boxed_primitive == STORAGE_SPEC_BP_NUM)) {
                    /* It's a boxed int or num; pretty easy. It'll just live in the
                     * body of the struct. */
                    repr_data->attribute_locations[i] = 0;
                    bits = spec.bits;
                    repr_data->flattened_stables[i] = STABLE(type);
                    if (REPR(type)->initialize) {
                        if (!repr_data->initialize_slots)
                            repr_data->initialize_slots = (INTVAL *) mem_sys_allocate_zeroed((info_alloc + 1) * sizeof(INTVAL));
                        repr_data->initialize_slots[cur_init_slot] = i;
                        cur_init_slot++;
                    }
                }
                else {
                    Parrot_ex_throw_from_c_args(interp, NULL, EXCEPTION_INVALID_OPERATION,
                        "CStruct representation only implements native int and float members so far");
                }
            }
            else {
                Parrot_ex_throw_from_c_args(interp, NULL, EXCEPTION_INVALID_OPERATION,
                    "CStruct representation requires the types of all attributes to be specified");
            }
            
            /* Do allocation. */
            /* XXX TODO C structure needs careful alignment */
            repr_data->struct_offsets[i] = cur_size;
            cur_size += bits / 8;
        }

        /* Finally, put computed allocation size in place; it's body size plus
         * header size. Also number of markables and sentinels. */
        repr_data->struct_size = cur_size;
        if (repr_data->initialize_slots)
            repr_data->initialize_slots[cur_init_slot] = -1;
    }

    Parrot_unblock_GC_mark(interp);
}

/* Helper for reading an int at the specified offset. */
static INTVAL get_int_at_offset(void *data, INTVAL offset) {
    void *location = (char *)data + offset;
    return *((INTVAL *)location);
}

/* Helper for writing an int at the specified offset. */
static void set_int_at_offset(void *data, INTVAL offset, INTVAL value) {
    void *location = (char *)data + offset;
    *((INTVAL *)location) = value;
}

/* Helper for reading a num at the specified offset. */
static FLOATVAL get_num_at_offset(void *data, INTVAL offset) {
    void *location = (char *)data + offset;
    return *((FLOATVAL *)location);
}

/* Helper for writing a num at the specified offset. */
static void set_num_at_offset(void *data, INTVAL offset, FLOATVAL value) {
    void *location = (char *)data + offset;
    *((FLOATVAL *)location) = value;
}

/* Helper for reading a pointer at the specified offset. */
static void * get_ptr_at_offset(void *data, INTVAL offset) {
    void *location = (char *)data + offset;
    return *((void **)location);
}

/* Helper for writing a pointer at the specified offset. */
static void set_ptr_at_offset(void *data, INTVAL offset, void *value) {
    void *location = (char *)data + offset;
    *((void **)location) = value;
}

/* Helper for finding a slot number. */
static INTVAL try_get_slot(PARROT_INTERP, CStructREPRData *repr_data, PMC *class_key, STRING *name) {
    INTVAL slot = -1;
    if (repr_data->name_to_index_mapping) {
        CStructNameMap *cur_map_entry = repr_data->name_to_index_mapping;
        while (cur_map_entry->class_key != NULL) {
            if (cur_map_entry->class_key == class_key) {
                PMC *slot_pmc = VTABLE_get_pmc_keyed_str(interp, cur_map_entry->name_map, name);
                if (!PMC_IS_NULL(slot_pmc))
                    slot = VTABLE_get_integer(interp, slot_pmc);
                break;
            }
            cur_map_entry++;
        }
    }
    return slot;
}

/* Creates a new type object of this representation, and associates it with
 * the given HOW. */
static PMC * type_object_for(PARROT_INTERP, PMC *HOW) {
    /* Create new object instance. */
    CStructInstance *obj = mem_allocate_zeroed_typed(CStructInstance);

    /* Build an STable. */
    PMC *st_pmc = create_stable_func(interp, this_repr, HOW);
    STable *st  = STABLE_STRUCT(st_pmc);
    
    /* Create REPR data structure and hang it off the STable. */
    st->REPR_data = mem_allocate_zeroed_typed(CStructREPRData);

    /* Create type object and point it back at the STable. */
    obj->common.stable = st_pmc;
    st->WHAT = wrap_object_func(interp, obj);
    PARROT_GC_WRITE_BARRIER(interp, st_pmc);

    /* Flag it as a type object. */
    MARK_AS_TYPE_OBJECT(st->WHAT);

    return st->WHAT;
}

/* Creates a new instance based on the type object. */
static PMC * allocate(PARROT_INTERP, STable *st) {
    CStructInstance * obj;

    /* Compute allocation strategy if we've not already done so. */
    CStructREPRData * repr_data = (CStructREPRData *) st->REPR_data;
    if (!repr_data->struct_size) {
        compute_allocation_strategy(interp, st->WHAT, repr_data);
        PARROT_GC_WRITE_BARRIER(interp, st->stable_pmc);
    }

    /* Allocate and set up object instance. */
    obj = (CStructInstance *) Parrot_gc_allocate_fixed_size_storage(interp, sizeof(CStructInstance));
    obj->common.stable = st->stable_pmc;
    /* XXX allocate child str and obj arrays if needed. */
    
    return wrap_object_func(interp, obj);
}

/* Initialize a new instance. */
static void initialize(PARROT_INTERP, STable *st, void *data) {
    CStructREPRData * repr_data = (CStructREPRData *) st->REPR_data;
    
    /* Allocate object body. */
    CStructBody *body = (CStructBody *)data;
    body->cstruct = mem_sys_allocate(repr_data->struct_size);
    memset(body->cstruct, 0, repr_data->struct_size);
    
    /* Initialize the slots. */
    if (repr_data->initialize_slots) {
        INTVAL i;
        for (i = 0; repr_data->initialize_slots[i] >= 0; i++) {
            INTVAL  offset = repr_data->struct_offsets[repr_data->initialize_slots[i]];
            STable *st     = repr_data->flattened_stables[repr_data->initialize_slots[i]];
            st->REPR->initialize(interp, st, (char *)body->cstruct + offset);
        }
    }
}

/* Copies to the body of one object to another. */
static void copy_to(PARROT_INTERP, STable *st, void *src, void *dest) {
    CStructREPRData * repr_data = (CStructREPRData *) st->REPR_data;
    CStructBody *src_body = (CStructBody *)src;
    CStructBody *dest_body = (CStructBody *)dest;
    /* XXX todo */
    /* XXX also need to shallow copy the obj and str arrays */
}

/* Helper for complaining about attribute access errors. */
PARROT_DOES_NOT_RETURN
static void no_such_attribute(PARROT_INTERP, const char *action, PMC *class_handle, STRING *name) {
    Parrot_ex_throw_from_c_args(interp, NULL, EXCEPTION_INVALID_OPERATION,
            "Can not %s non-existent attribute '%Ss' on class '%Ss'",
            action, name, VTABLE_get_string(interp, introspection_call(interp,
                class_handle, STABLE(class_handle)->HOW,
                Parrot_str_new_constant(interp, "name"), 0)));
}

/* Helper to die because this type doesn't support attributes. */
PARROT_DOES_NOT_RETURN
static void die_no_attrs(PARROT_INTERP) {
    Parrot_ex_throw_from_c_args(interp, NULL, EXCEPTION_INVALID_OPERATION,
            "CStruct representation attribute not yet fully implemented");
}

/* Gets the current value for an attribute. */
static PMC * get_attribute_boxed(PARROT_INTERP, STable *st, void *data, PMC *class_handle, STRING *name, INTVAL hint) {
    die_no_attrs(interp);
}
static void * get_attribute_ref(PARROT_INTERP, STable *st, void *data, PMC *class_handle, STRING *name, INTVAL hint) {
    CStructREPRData *repr_data = (CStructREPRData *)st->REPR_data;
    CStructBody     *body      = (CStructBody *)data;
    INTVAL           slot;

    /* Look up slot, then offset and compute address. */
    slot = hint >= 0 ? hint :
        try_get_slot(interp, repr_data, class_handle, name);
    if (slot >= 0)
        return ((char *)body->cstruct) + repr_data->struct_offsets[slot];
    
    /* Otherwise, complain that the attribute doesn't exist. */
    no_such_attribute(interp, "get", class_handle, name);
}

/* Binds the given value to the specified attribute. */
static void bind_attribute_boxed(PARROT_INTERP, STable *st, void *data, PMC *class_handle, STRING *name, INTVAL hint, PMC *value) {
    die_no_attrs(interp);
}
static void bind_attribute_ref(PARROT_INTERP, STable *st, void *data, PMC *class_handle, STRING *name, INTVAL hint, void *value) {
    CStructREPRData *repr_data = (CStructREPRData *)st->REPR_data;
    CStructBody     *body      = (CStructBody *)data;
    INTVAL            slot;

    /* Try to find the slot. */
    slot = hint >= 0 ? hint :
        try_get_slot(interp, repr_data, class_handle, name);
    if (slot >= 0) {
        STable *st = repr_data->flattened_stables[slot];
        if (st)
            st->REPR->copy_to(interp, st, value, ((char *)body->cstruct) + repr_data->struct_offsets[slot]);
        else
            Parrot_ex_throw_from_c_args(interp, NULL, EXCEPTION_INVALID_OPERATION,
                "Can not bind by reference to non-flattened attribute '%Ss' on class '%Ss'",
                name, VTABLE_get_string(interp, introspection_call(interp,
                    class_handle, STABLE(class_handle)->HOW,
                    Parrot_str_new_constant(interp, "name"), 0)));
    }
    else {
        /* Otherwise, complain that the attribute doesn't exist. */
        no_such_attribute(interp, "bind", class_handle, name);
    }
}

/* Checks if an attribute has been initialized. */
static INTVAL is_attribute_initialized(PARROT_INTERP, STable *st, void *data, PMC *ClassHandle, STRING *Name, INTVAL Hint) {
    die_no_attrs(interp);
}

/* Gets the hint for the given attribute ID. */
static INTVAL hint_for(PARROT_INTERP, STable *st, PMC *class_handle, STRING *name) {
    return NO_HINT;
}

/* This Parrot-specific addition to the API is used to mark an object. */
static void gc_mark(PARROT_INTERP, STable *st, void *data) {
    CStructREPRData *repr_data = (CStructREPRData *) st->REPR_data;
    CStructBody *body = (CStructBody *)data;
    INTVAL i;
    for (i = 0; i < repr_data->num_child_objs; i++)
        Parrot_gc_mark_PMC_alive(interp, body->child_objs[i]);
}

/* This is called to do any cleanup of resources when an object gets
 * embedded inside another one. Never called on a top-level object. */
static void gc_cleanup(PARROT_INTERP, STable *st, void *data) {
    CStructBody *body = (CStructBody *)data;
    if (body->child_objs)
        mem_sys_free(body->child_objs);
    if (body->cstruct)
        mem_sys_free(body->cstruct);
}

/* This Parrot-specific addition to the API is used to free an object. */
static void gc_free(PARROT_INTERP, PMC *obj) {
    CStructREPRData *repr_data = (CStructREPRData *)STABLE(obj)->REPR_data;
	gc_cleanup(interp, STABLE(obj), OBJECT_BODY(obj));
    if (IS_CONCRETE(obj))
		Parrot_gc_free_fixed_size_storage(interp, sizeof(CStructInstance), PMC_data(obj));
	else
		mem_sys_free(PMC_data(obj));
    PMC_data(obj) = NULL;
}

/* Gets the storage specification for this representation. */
static storage_spec get_storage_spec(PARROT_INTERP, STable *st) {
    storage_spec spec;
    spec.inlineable = STORAGE_SPEC_REFERENCE;
    spec.boxed_primitive = STORAGE_SPEC_BP_NONE;
    spec.can_box = 0;
    return spec;
}

/* Initializes the CStruct representation. */
REPROps * CStruct_initialize(PARROT_INTERP,
        PMC * (* wrap_object_func_ptr) (PARROT_INTERP, void *obj),
        PMC * (* create_stable_func_ptr) (PARROT_INTERP, REPROps *REPR, PMC *HOW)) {
    /* Stash away functions passed wrapping functions. */
    wrap_object_func = wrap_object_func_ptr;
    create_stable_func = create_stable_func_ptr;

    /* Allocate and populate the representation function table. */
    this_repr = mem_allocate_zeroed_typed(REPROps);
    this_repr->type_object_for = type_object_for;
    this_repr->allocate = allocate;
    this_repr->initialize = initialize;
    this_repr->copy_to = copy_to;
    this_repr->attr_funcs = mem_allocate_typed(REPROps_Attribute);
    this_repr->attr_funcs->get_attribute_boxed = get_attribute_boxed;
    this_repr->attr_funcs->get_attribute_ref = get_attribute_ref;
    this_repr->attr_funcs->bind_attribute_boxed = bind_attribute_boxed;
    this_repr->attr_funcs->bind_attribute_ref = bind_attribute_ref;
    this_repr->attr_funcs->is_attribute_initialized = is_attribute_initialized;
    this_repr->attr_funcs->hint_for = hint_for;
    this_repr->gc_mark = gc_mark;
    this_repr->gc_free = gc_free;
    this_repr->gc_cleanup = gc_cleanup;
    this_repr->get_storage_spec = get_storage_spec;
    return this_repr;
}
