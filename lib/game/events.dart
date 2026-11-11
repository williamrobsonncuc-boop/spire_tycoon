/// Things that can happen while the tower is open.
///
/// A courier and a party wait until you tap them. A market boom doubles
/// gold for a minute, then quietly ends. A power outage pauses income
/// until you tap the lights back on. None of these vanish as a penalty.
enum OfficeEvent { courier, boom, party, outage }

/// Returns the event for a saved name, or null when the name is unknown.
OfficeEvent? officeEventFromName(String? name) {
  for (final event in OfficeEvent.values) {
    if (event.name == name) {
      return event;
    }
  }
  return null;
}
