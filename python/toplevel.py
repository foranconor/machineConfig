from interpreter import *

def tool_change(self, **params):
    # Extract pocket info from interpreter state - not accessible in ngc remap context
    self.params["next_pocket"]    = float(self.selected_pocket)
    self.params["current_pocket"] = float(self.current_pocket)
    self.params["next_tool"]      = float(self.selected_tool)

    # Motion sequence handled in ngc
    self.execute("O<tool_change> call")

    # Update tool in spindle (M61 sets tool number without triggering hardware change)
    self.execute(f"M61 Q{int(self.selected_tool)}")

    return INTERP_OK
