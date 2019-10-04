def suffix_variadic(name, index, arity):
    return name + ('' if arity == 1 else str(index))

def list_with_suffix_variadic(name, arity):
    return [suffix_variadic(name, i, arity) for i in range(arity)]
