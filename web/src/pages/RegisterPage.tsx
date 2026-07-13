import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";

import { useAuth } from "../auth/AuthContext";
import type { Role } from "../api/types";
import { errMessage } from "../components/useAsync";

// Self-service registration is limited to buyer/seller (the backend rejects
// support/admin here — those are provisioned out-of-band).
export function RegisterPage() {
  const { register } = useAuth();
  const navigate = useNavigate();

  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [role, setRole] = useState<Role>("buyer");
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    if (password.length < 8) {
      setError("Password must be at least 8 characters.");
      return;
    }
    setSubmitting(true);
    try {
      await register(name.trim(), email.trim(), password, role);
      navigate("/", { replace: true });
    } catch (err) {
      setError(errMessage(err));
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="auth-layout">
      <form className="card auth-card" onSubmit={submit}>
        <h1>Create account</h1>
        {error && <div className="form-error">{error}</div>}
        <label>
          Name
          <input value={name} onChange={(e) => setName(e.target.value)} required />
        </label>
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
            autoComplete="new-password"
            minLength={8}
            required
          />
          <span className="hint">At least 8 characters.</span>
        </label>
        <fieldset className="role-picker">
          <legend>I want to</legend>
          <label className="radio">
            <input type="radio" name="role" checked={role === "buyer"} onChange={() => setRole("buyer")} />
            Buy items
          </label>
          <label className="radio">
            <input type="radio" name="role" checked={role === "seller"} onChange={() => setRole("seller")} />
            Sell items
          </label>
        </fieldset>
        <button className="btn btn-primary btn-block" type="submit" disabled={submitting}>
          {submitting ? "Creating…" : "Create account"}
        </button>
        <p className="auth-alt">
          Already have an account? <Link to="/login">Log in</Link>
        </p>
      </form>
    </div>
  );
}
