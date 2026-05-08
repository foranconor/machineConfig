def m6_prolog(self, **words):
    self.params["next_pocket"]    = float(self.selected_pocket)
    self.params["current_pocket"] = float(self.current_pocket)
    self.params["next_tool"]      = float(self.selected_tool)
    return 0
