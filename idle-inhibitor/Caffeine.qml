pragma Singleton

import Quickshell

// Shared caffeine state. The bar pill is the control; CaffeineToggle is the
// component that turns this flag into a Wayland idle-inhibit request.
Singleton {
  id: root

  property bool active: false

  function toggle(): void {
    root.active = !root.active;
  }
}
