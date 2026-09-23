export class WclError extends Error {
  constructor(message, { code = 'WCL_ERROR', status, cause } = {}) {
    super(message, { cause });
    this.name = 'WclError';
    this.code = code;
    this.status = status;
  }
}

export class WclAuthError extends WclError {
  constructor(message, options = {}) {
    super(message, { ...options, code: 'WCL_AUTH_ERROR' });
    this.name = 'WclAuthError';
  }
}

export class WclHttpError extends WclError {
  constructor(message, options = {}) {
    super(message, { ...options, code: 'WCL_HTTP_ERROR' });
    this.name = 'WclHttpError';
  }
}

export class WclGraphQLError extends WclError {
  constructor(message, options = {}) {
    super(message, { ...options, code: 'WCL_GRAPHQL_ERROR' });
    this.name = 'WclGraphQLError';
  }
}

export class WclValidationError extends WclError {
  constructor(message, options = {}) {
    super(message, { ...options, code: 'WCL_VALIDATION_ERROR' });
    this.name = 'WclValidationError';
  }
}

export class WclNotFoundError extends WclError {
  constructor(message, options = {}) {
    super(message, { ...options, code: 'WCL_NOT_FOUND' });
    this.name = 'WclNotFoundError';
  }
}
