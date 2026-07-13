import * as api from "../../api/endpoints";
import { useAuth } from "../../auth/AuthContext";
import type { Role, User } from "../../api/types";
import { Badge, ErrorState, Spinner, statusTone } from "../../components/ui";
import { errMessage, useAsync } from "../../components/useAsync";

const ROLES: Role[] = ["buyer", "seller", "support", "admin"];

export function AdminUsersPage() {
  const { user: me } = useAuth();
  const { data: users, loading, error, reload } = useAsync(() => api.adminListUsers(), []);

  const patch = async (u: User, body: { banned?: boolean; role?: Role }) => {
    try {
      await api.adminPatchUser(u.id, body);
      reload();
    } catch (err) {
      alert(errMessage(err));
    }
  };

  return (
    <div className="page">
      <div className="page-head">
        <h1>User moderation</h1>
      </div>

      {loading && <Spinner />}
      {error && <ErrorState message={error} />}
      {!loading && !error && users && (
        <table className="table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Email</th>
              <th>Role</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {users.map((u) => {
              const isSelf = u.id === me?.id;
              return (
                <tr key={u.id}>
                  <td>
                    {u.name}
                    {isSelf && <span className="muted"> (you)</span>}
                  </td>
                  <td>{u.email}</td>
                  <td>
                    <select
                      value={u.role}
                      disabled={isSelf}
                      onChange={(e) => patch(u, { role: e.target.value as Role })}
                    >
                      {ROLES.map((r) => (
                        <option key={r} value={r}>
                          {r}
                        </option>
                      ))}
                    </select>
                  </td>
                  <td>
                    <Badge tone={u.banned ? statusTone("banned") : "green"}>{u.banned ? "banned" : "active"}</Badge>
                  </td>
                  <td className="row-actions">
                    {!isSelf && (
                      <button
                        className={`btn btn-sm ${u.banned ? "btn-ghost" : "btn-danger"}`}
                        onClick={() => patch(u, { banned: !u.banned })}
                      >
                        {u.banned ? "Unban" : "Ban"}
                      </button>
                    )}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      )}
    </div>
  );
}
