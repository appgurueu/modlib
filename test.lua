local t = {}
t[t] = t

local t2 = modlib.table.deepcopy(t)
assert(t2[t2] == t2)

assert(modlib.table.equals_noncircular({[{}]={}}, {[{}]={}}))