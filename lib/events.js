/**
 * Create a standardized event object.
 * @param {string} eventType - Type of event.
 * @param {any} payload - Event payload.
 * @param {string} source - Event source identifier.
 * @param {object} [extras={}] - Additional metadata.
 * @returns {object} JSON-serializable event object.
 */
function createEvent(eventType, payload, source, extras = {}) {
  return {
    event_type: eventType,
    version: "1.0",
    timestamp: new Date().toISOString(),
    payload,
    meta: { source, ...extras }
  };
}

/**
 * Stringify an event object to JSON.
 * @param {object} eventObj - Event object.
 * @returns {string} JSON string.
 */
function stringifyEvent(eventObj) {
  return JSON.stringify(eventObj);
}

module.exports = { createEvent, stringifyEvent };
