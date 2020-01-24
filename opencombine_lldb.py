# To use `opencombine_lldb.py`, figure out its full path.
# Let's say the full path is `~/projects/OpenCombine/opencombine_lldb.py`.
# Then add the following statement to your `~/.lldbinit` file:
#
#     command script import ~/projects/OpenCombine/opencombine_lldb.py

import lldb

# Show a Demand as either `max(N)` or `unlimited`.
def summary_Demand(sb_value, internal_dict):
    child = sb_value.GetChildAtIndex(0)
    if not child.IsValid():
        return 'failed to get child of Demand'
    number = child.GetValueAsUnsigned()

    # .unlimited is represented by a rawValue of UInt(Int.max) + 1.
    # Int.max is either 2**31 - 1 or 2**63 - 1 depending on the
    # target platform. So .unlimited is either 2**31 or 2**63.
    #     31 = 4 * 8 - 1
    #     63 = 8 * 8 - 1
    unlimited = 2**(child.GetByteSize() * 8 - 1)

    if number == unlimited:
        return 'unlimited'
    else:
        return 'max(%d)' % number

def __lldb_init_module(debugger, internal_dict):
    debugger.HandleCommand('type summary add -w swift OpenCombine.Subscribers.Demand -F "' + __name__ + '.summary_Demand"')
