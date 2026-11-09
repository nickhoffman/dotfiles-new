# Bluetooth device IDs
trackpad_id='d8-96-95-e1-c8-08'   # Nick Hoffman's Trackpad
keyboard_id='c8-e0-eb-0f-a0-9a'   # Nick Hoffman’s Keyboard

bt_cmd='blueutil'

$bt_cmd --power | grep -q '^1$'
if [[ "x$?" = 'x0' ]]; then
  # Disconnect the devices and turn off Bluetooth
  $bt_cmd --disconnect "$trackpad_id"
  $bt_cmd --disconnect "$keyboard_id"
  $bt_cmd --power 0
  say 'disconnected'
else
  # Turn on Bluetooth and connect the devices
  $bt_cmd --power 1
  $bt_cmd --connect "$trackpad_id"
  $bt_cmd --connect "$keyboard_id"
  say 'connected'
fi
