using System.Security.Cryptography;
using System.Text;

namespace SimpleRDP.Services;

/// <summary>
/// Encrypts/decrypts a password with Windows DPAPI, scoped to the current user.
/// The blob is only readable by the same Windows account on the same machine.
/// </summary>
public static class CredentialProtector
{
    public static string Protect(string plain)
    {
        var bytes = Encoding.UTF8.GetBytes(plain);
        var enc = ProtectedData.Protect(bytes, optionalEntropy: null, DataProtectionScope.CurrentUser);
        return Convert.ToBase64String(enc);
    }

    /// <summary>Returns the plaintext, or null if the blob can't be decrypted (e.g. different user).</summary>
    public static string? TryUnprotect(string base64)
    {
        try
        {
            var enc = Convert.FromBase64String(base64);
            var bytes = ProtectedData.Unprotect(enc, optionalEntropy: null, DataProtectionScope.CurrentUser);
            return Encoding.UTF8.GetString(bytes);
        }
        catch
        {
            return null;
        }
    }
}
