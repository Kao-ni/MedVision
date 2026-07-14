export class AppError extends Error {
  constructor(message, { code = "app_error", status = 500, details = null } = {}) {
    super(message);
    this.name = "AppError";
    this.code = code;
    this.status = status;
    this.details = details;
  }
}

export class ValidationError extends AppError {
  constructor(message, details = null) {
    super(message, { code: "validation_error", status: 400, details });
    this.name = "ValidationError";
  }
}

export class UpstreamError extends AppError {
  constructor(message, details = null) {
    super(message, { code: "upstream_error", status: 502, details });
    this.name = "UpstreamError";
  }
}
