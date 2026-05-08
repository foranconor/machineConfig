def m6_prolog(self, **words):
    try:
        if self.selected_pocket < 0:
            return "T%d: not in tool table" % self.selected_tool
        self.params["tool_in_spindle"] = float(self.current_pocket)
        self.params["current_pocket"]  = float(self.current_pocket)
        self.params["next_pocket"]     = float(self.selected_pocket)
        self.params["next_tool"]       = float(self.selected_tool)
        return 0
    except Exception as e:
        return str(e)

def m6_epilog(self, **words):
    try:
        if self.return_value > 0.5:
            self.set_tool_parameters()
            return 0
        return "tool_change returned %.1f, expected positive" % self.return_value
    except Exception as e:
        return str(e)
