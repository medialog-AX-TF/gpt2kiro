[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [AllowEmptyString()]
    [string]$Text
)

begin {
    $ErrorActionPreference = 'Stop'
}

process {
    $value = $Text

    # Common secret assignments. Keep the key name, remove the value.
    $value = [regex]::Replace(
        $value,
        '(?im)\b(api[_-]?key|access[_-]?token|refresh[_-]?token|token|password|passwd|secret|client[_-]?secret)\b\s*[:=]\s*["'']?[^\s"''`,;]+',
        '$1=[REDACTED_SECRET]'
    )

    # PEM/private-key material.
    $value = [regex]::Replace(
        $value,
        '(?is)-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----.*?-----END (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',
        '[REDACTED_PRIVATE_KEY]'
    )

    # Email addresses.
    $value = [regex]::Replace(
        $value,
        '(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b',
        '[REDACTED_EMAIL]'
    )

    # Korean mobile / common telephone forms.
    $value = [regex]::Replace(
        $value,
        '(?<!\d)(?:\+?82[- .]?)?(?:0?1[016789]|0[2-6][1-5]?)[- .]?\d{3,4}[- .]?\d{4}(?!\d)',
        '[REDACTED_PHONE]'
    )

    # IPv4 addresses. This intentionally favors privacy over preserving literal IPs in memory.
    $value = [regex]::Replace(
        $value,
        '(?<!\d)(?:(?:25[0-5]|2[0-4]\d|1?\d?\d)\.){3}(?:25[0-5]|2[0-4]\d|1?\d?\d)(?!\d)',
        '[REDACTED_IP]'
    )

    # Windows local user profile path.
    $value = [regex]::Replace(
        $value,
        '(?i)\b([A-Z]:\\Users\\)[^\\\s]+',
        '$1[REDACTED_USER]'
    )

    # Domain/local-machine account notation such as DOMAIN\user.
    $value = [regex]::Replace(
        $value,
        '(?i)(?<![A-Z0-9_.-])(?:[A-Z0-9_.-]+)\\(?:[A-Z0-9_.-]+)(?![A-Z0-9_.-])',
        '[REDACTED_ACCOUNT]'
    )

    $value
}
