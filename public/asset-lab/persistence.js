// Storage can fail even when the controller state is valid.
export function saveConfiguration(storage, key, snapshot, slots) {
  try {
    storage.setItem(key, JSON.stringify(snapshot));
    storage.setItem(key + '-slots', JSON.stringify(slots));
    return true;
  } catch {
    return false;
  }
}
