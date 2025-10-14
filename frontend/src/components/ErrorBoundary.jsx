import React from 'react';

/**
 * Error Boundary Component for catching React errors in development and production
 * Prevents the entire app from crashing due to component errors
 */
class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null, errorInfo: null };
  }

  static getDerivedStateFromError(error) {
    // Update state so the next render will show the fallback UI
    return { hasError: true };
  }

  componentDidCatch(error, errorInfo) {
    // Log error details in development
    if (process.env.NODE_ENV === 'development') {
      console.group('🚨 React Error Boundary Caught Error');
      console.error('Error:', error);
      console.error('Error Info:', errorInfo);
      console.error('Component Stack:', errorInfo.componentStack);
      console.groupEnd();
    }

    // Store error details in state for debugging
    this.setState({
      error,
      errorInfo
    });

    // Report error to external service in production
    if (process.env.NODE_ENV === 'production') {
      // TODO: Add error reporting service like Sentry
      console.error('Production Error:', error);
    }
  }

  render() {
    if (this.state.hasError) {
      const { fallback: Fallback, children } = this.props;
      
      // Use custom fallback if provided
      if (Fallback) {
        return <Fallback error={this.state.error} errorInfo={this.state.errorInfo} />;
      }

      // Default fallback UI
      return (
        <div className="error-boundary">
          <div className="error-boundary-content">
            <h2>🚨 Something went wrong</h2>
            <p>A component error occurred. The page has been recovered.</p>
            
            {process.env.NODE_ENV === 'development' && (
              <details className="error-details">
                <summary>Show Error Details (Development Mode)</summary>
                <div className="error-info">
                  <h4>Error:</h4>
                  <pre>{this.state.error && this.state.error.toString()}</pre>
                  
                  <h4>Component Stack:</h4>
                  <pre>{this.state.errorInfo.componentStack}</pre>
                </div>
              </details>
            )}
            
            <button 
              onClick={() => this.setState({ hasError: false, error: null, errorInfo: null })}
              className="btn btn-primary"
            >
              Try Again
            </button>
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}

/**
 * HOC to wrap components with error boundary
 */
export const withErrorBoundary = (WrappedComponent, fallback = null) => {
  const ComponentWithErrorBoundary = (props) => (
    <ErrorBoundary fallback={fallback}>
      <WrappedComponent {...props} />
    </ErrorBoundary>
  );
  
  ComponentWithErrorBoundary.displayName = `withErrorBoundary(${WrappedComponent.displayName || WrappedComponent.name})`;
  
  return ComponentWithErrorBoundary;
};

export default ErrorBoundary;