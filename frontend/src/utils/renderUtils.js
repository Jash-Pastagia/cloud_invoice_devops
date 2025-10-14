/**
 * Utility functions for safe rendering in React components
 */

/**
 * Safely render customer name, preventing React error #31 from object rendering
 * @param {string|object} customer - Customer data (string name or object with name property)
 * @returns {string} - Safe string representation of customer name
 */
export const safeRenderCustomer = (customer) => {
  if (typeof customer === 'string') {
    return customer;
  }
  if (typeof customer === 'object' && customer !== null) {
    // Use safeRender to ensure nested objects become safe strings
    if (customer.name !== undefined) return safeRender(customer.name, 'N/A')
    if (customer.fullName !== undefined) return safeRender(customer.fullName, 'N/A')
    if (customer.displayName !== undefined) return safeRender(customer.displayName, 'N/A')
    return 'N/A'
  }
  return 'N/A';
};

/**
 * Safely render any data that might be an object or primitive
 * @param {any} data - Data to render
 * @param {string} fallback - Fallback string if data is not renderable
 * @returns {string} - Safe string representation
 */
export const safeRender = (data, fallback = 'N/A') => {
  if (data === null || data === undefined) {
    return fallback;
  }
  if (typeof data === 'string' || typeof data === 'number') {
    return String(data);
  }
  if (typeof data === 'object') {
    // For objects, try common name fields first
    if (data.name) return String(data.name);
    if (data.title) return String(data.title);
    if (data.label) return String(data.label);
    // If it's an array, join it
    if (Array.isArray(data)) {
      return data.map(item => safeRender(item, '')).filter(Boolean).join(', ') || fallback;
    }
    return fallback;
  }
  return String(data);
};

// SafeComponent removed to avoid JSX in .js file
// Use direct component validation in components instead