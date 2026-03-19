# Contributing to Docker TensorFlow Template

Thank you for your interest in contributing to the Docker TensorFlow Template! This document provides guidelines and instructions for contributing.

## Code of Conduct

By participating in this project, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md).

## How Can I Contribute?

### Reporting Bugs
- Use the [bug report template](.github/ISSUE_TEMPLATE/bug_report.md)
- Include detailed steps to reproduce
- Include environment information
- Include relevant logs and screenshots

### Suggesting Enhancements
- Use the [feature request template](.github/ISSUE_TEMPLATE/feature_request.md)
- Clearly describe the use case
- Explain why this enhancement would be useful
- Consider if it aligns with the project goals

### Pull Requests
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add or update tests as needed
5. Update documentation
6. Commit your changes (`git commit -m 'Add some amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

## Development Setup

### Prerequisites
- Docker 20.10+
- Python 3.10+
- Git

### Local Development
```bash
# Clone the repository
git clone https://github.com/aioperations-io/docker-tensorflow.git
cd docker-tensorflow

# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Run tests
./scripts/test.sh --type unit

# Build Docker images
./scripts/build.sh --type cpu
```

### Testing
```bash
# Run all tests
./scripts/test.sh --type all

# Run specific test types
./scripts/test.sh --type unit
./scripts/test.sh --type integration
./scripts/test.sh --type e2e
./scripts/test.sh --type performance
```

## Project Structure

```
docker-tensorflow/
├── .github/                    # GitHub workflows and templates
├── config/                     # Configuration files
├── docs/                       # Documentation
├── scripts/                    # Automation scripts
├── src/                        # Source code
│   ├── train.py               # Training script
│   ├── serve.py               # Serving script
│   └── models/                # Model definitions
├── Dockerfile.cpu             # CPU optimized Dockerfile
├── Dockerfile.gpu             # GPU optimized Dockerfile
├── docker-compose.yml         # Multi-service deployment
├── requirements.txt           # Python dependencies
└── README.md                  # Project documentation
```

## Coding Standards

### Python Code
- Follow [PEP 8](https://www.python.org/dev/peps/pep-0008/) style guide
- Use type hints where appropriate
- Write docstrings for all public functions and classes
- Keep functions small and focused

### Docker Configuration
- Use multi-stage builds for smaller images
- Specify exact versions for base images
- Use non-root users for security
- Include health checks
- Optimize layer caching

### Documentation
- Keep README.md up to date
- Document all configuration options
- Include examples for common use cases
- Update API documentation when changing interfaces

## Commit Messages

Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

Example:
```
feat: add GPU support for TensorFlow 2.15

- Update Dockerfile.gpu with CUDA 12.2
- Add GPU health checks
- Update documentation

Closes #123
```

## Review Process

1. **Automated Checks**: All PRs must pass CI checks
2. **Code Review**: At least one maintainer must approve
3. **Testing**: All new code must have tests
4. **Documentation**: All changes must be documented
5. **Backward Compatibility**: Consider impact on existing users

## Release Process

1. **Version Bumping**: Update version in relevant files
2. **Changelog**: Update CHANGELOG.md with changes
3. **Tagging**: Create git tag with version number
4. **Building**: CI/CD pipeline builds and publishes artifacts
5. **Documentation**: Update documentation if needed
6. **Announcement**: Notify community of new release

## Getting Help

- **Issues**: Use GitHub Issues for bug reports and feature requests
- **Discussions**: Use GitHub Discussions for questions and ideas
- **Email**: contact@aioperations.io for private matters

## Recognition

Contributors will be:
- Listed in the CONTRIBUTORS.md file
- Acknowledged in release notes
- Featured in project documentation (with permission)

## License

By contributing, you agree that your contributions will be licensed under the project's [MIT License](LICENSE).

Thank you for contributing to making AI operations more accessible and efficient! 🚀