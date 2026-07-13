import { useState } from "react";
import { Link, useLocation, useNavigate } from "react-router-dom";

import { useAuth } from "../auth/AuthContext";
import { errMessage } from "../components/useAsync";

// Demo accounts seeded by the backend (SEED_DEMO_DATA=true). Shown here so the
// baseline is explorable immediately; documented in the README too.
const DEMO_ACCOUNTS: { role: string; email: string }[] = [
  { role: "buyer", email: "buyer@example.com" },
  { role: "seller", email: "seller@example.com" },
  { role: "support", email: "support@example.com" },
  { role: "admin", email: "admin@example.com" },
];
const DEMO_PASSWORD = "Password123!";

export function LoginPage() {
  const { login } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const from = (location.state as { from?: string } | null)?.from ?? "/";

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setSubmitting(true);
    try {
      await login(email.trim(), password);
      navigate(from, { replace: true });
    } catch (err) {
      setError(errMessage(err));
    } finally {
      setSubmitting(false);
    }
  };

  const fillDemo = (demoEmail: string) => {
    setEmail(demoEmail);
    setPassword(DEMO_PASSWORD);
  };

  return (
    <div className="auth-layout">
      <form className="card auth-card" onSubmit={submit}>
        <h1>Log in</h1>
        {error && <div className="form-error">{error}</div>}
        <label>
          Email
          <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} autoComplete="email" required />
        </label>
        <label>
          Password
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete="current-password"
            required
          />
        </label>
        <button className="btn btn-primary btn-block" type="submit" disabled={submitting}>
          {submitting ? "Logging in…" : "Log in"}
        </button>
        <p className="auth-alt">
          No account? <Link to="/register">Sign up</Link>
        </p>
      </form>

      <div className="card demo-card">
        <h2>Demo accounts</h2>
        <p className="muted">Password for all: <code>{DEMO_PASSWORD}</code></p>
        <ul className="demo-list">
          {DEMO_ACCOUNTS.map((a) => (
            <li key={a.email}>
              <span className="badge badge-blue">{a.role}</span>
              <code>{a.email}</code>
              <button type="button" className="btn btn-ghost btn-sm" onClick={() => fillDemo(a.email)}>
                Use
              </button>
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}
