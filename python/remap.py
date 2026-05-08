import os

_config_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

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
            _save_tool_state(self.selected_tool)
            return 0
        return "tool_change returned %.1f, expected positive" % self.return_value
    except Exception as e:
        return str(e)

def _save_tool_state(tool_no):
    path = os.path.join(_config_dir, 'state', 'tool_restore.ngc')
    with open(path, 'w') as f:
        f.write('O<tool_restore> sub\n  M61 Q%d\nO<tool_restore> endsub\n' % int(tool_no))
