//
//  hash_dic.h
//  Metal4C
//
//  Created by Michael Larson on 2/19/26.
//

// to give credit where due
// copied from https://github.com/exebook/hashdict.c


#ifndef hash_dic_h
#define hash_dic_h

#include <stdlib.h> /* malloc/calloc */
#include <stdint.h> /* uint32_t */
#include <string.h> /* memcpy/memcmp */

typedef int (*enumFunc)(void *key, int count, int *value, void *user);

#define HASHDICT_VALUE_TYPE void *
#define KEY_LENGTH_TYPE uint8_t

struct keynode {
    struct keynode *next;
    char *key;
    KEY_LENGTH_TYPE len;
    HASHDICT_VALUE_TYPE value;
};
        
typedef struct dictionary {
    struct keynode **table;
    int length, count;
    double growth_treshold;
    double growth_factor;
    HASHDICT_VALUE_TYPE *value;
} HashDictionary;

/* See README.md */

struct dictionary* dic_new(int initial_size);
void dic_delete(struct dictionary* dic);
int dic_add(struct dictionary* dic, void *key, int keyn);
int dic_find(struct dictionary* dic, void *key, int keyn);
void dic_forEach(struct dictionary* dic, enumFunc f, void *user);


#endif /* hash_dic_h */
