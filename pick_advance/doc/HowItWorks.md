## How it works (draft notes)

dialog "set" actions:

* client (local only)
* unit.advances_to
* wml.variables
* unit.variables.base_type = current type

1. leave as is if base_type == current type
recruit, post advance events:

2. get from wml.variables, set, go to 4
3. get from client, publicly set
4. set unit.variables.base_type = current type
