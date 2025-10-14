// Export React for validation functions
import React from 'react';

/**
 * Development utilities for debugging React issues
 * Only runs in development mode
 */

/**
 * Validate JSX props to prevent invalid element type errors
 * @param {string} componentName - Name of the component for logging
 * @param {object} props - Props to validate
 */
export const validateProps = (componentName, props) => {
  if (process.env.NODE_ENV !== 'development') return;

  Object.entries(props).forEach(([key, value]) => {
    // Check for objects being passed where strings are expected
    if (typeof value === 'object' && value !== null && !React.isValidElement(value)) {
      console.warn(
        `⚠️ [${componentName}] Prop "${key}" is an object. This might cause React error #31 if rendered directly in JSX.`,
        'Value:', value,
        'Consider using safeRender() or accessing specific properties like value.name'
      );
    }

    // Check for undefined components
    if (key.toLowerCase().includes('component') && (value === undefined || value === null)) {
      console.warn(
        `⚠️ [${componentName}] Prop "${key}" is ${value}. This will cause "Element type is invalid" error.`
      );
    }
  });
};

/**
 * Log component render information in development
 * @param {string} componentName - Name of the component
 * @param {object} data - Data being rendered
 */
export const logRender = (componentName, data) => {
  if (process.env.NODE_ENV !== 'development') return;

  console.group(`🔍 [${componentName}] Render Debug`);
  console.log('Data:', data);
  console.log('Data type:', typeof data);
  console.log('Is array:', Array.isArray(data));
  console.log('Keys:', data && typeof data === 'object' ? Object.keys(data) : 'N/A');
  console.groupEnd();
};

/**
 * Validate that imported modules export valid React components
 * @param {object} imports - Object containing imported modules
 */
export const validateImports = (imports) => {
  if (process.env.NODE_ENV !== 'development') return;

  Object.entries(imports).forEach(([name, importedValue]) => {
    if (importedValue === undefined) {
      console.error(`🚨 Import Error: "${name}" is undefined. Check the export/import statements.`);
    } else if (typeof importedValue === 'object' && !React.isValidElement(importedValue) && typeof importedValue !== 'function') {
      console.warn(`⚠️ Import Warning: "${name}" is an object, not a React component. Using it as <${name} /> will cause error #31.`);
    }
  });
};

/**
 * Runtime check for React elements
 * @param {any} element - Element to check
 * @param {string} context - Context for error reporting
 */
export const validateElement = (element, context = 'Unknown') => {
  if (process.env.NODE_ENV !== 'development') return element;

  if (element && typeof element === 'object' && !React.isValidElement(element)) {
    console.error(
      `🚨 [${context}] Invalid React element:`,
      element,
      'This will cause "Objects are not valid as a React child" error.'
    );
  }

  return element;
};