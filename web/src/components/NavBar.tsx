// Top navigation. Links are role-scoped so each user only sees the screens
// their role can reach.

import { NavLink, useNavigate } from "react-router-dom";

import { useAuth } from "../auth/AuthContext";
import type { Role } from "../api/types";
import { Badge } from "./ui";

interface NavItem {
  to: string;
  label: string;
  roles?: Role[];
}

const NAV_ITEMS: NavItem[] = [
  { to: "/", label: "Browse" },
  { to: "/favorites", label: "Favorites", roles: ["buyer"] },
  { to: "/inquiries", label: "My Inquiries", roles: ["buyer"] },
  { to: "/seller/listings", label: "My Listings", roles: ["seller"] },
  { to: "/seller/inquiries", label: "Inquiries Inbox", roles: ["seller"] },
  { to: "/support/disputes", label: "Disputes", roles: ["support", "admin"] },
  { to: "/admin/users", label: "Users", roles: ["admin"] },
  { to: "/admin/listings", label: "Moderation", roles: ["admin"] },
  { to: "/admin/audit", label: "Audit", roles: ["admin"] },
];

export function NavBar() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();

  const visible = NAV_ITEMS.filter((item) => !item.roles || (user && item.roles.includes(user.role)));

  const handleLogout = () => {
    logout();
    navigate("/login");
  };

  return (
    <header className="navbar">
      <div className="navbar-inner">
        <NavLink to="/" className="brand">
          🛒 Marketplace
        </NavLink>

        <nav className="nav-links">
          {visible.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.to === "/"}
              className={({ isActive }) => (isActive ? "nav-link active" : "nav-link")}
            >
              {item.label}
            </NavLink>
          ))}
        </nav>

        <div className="nav-user">
          {user ? (
            <>
              <span className="nav-username">
                {user.name} <Badge tone="blue">{user.role}</Badge>
              </span>
              <button className="btn btn-ghost" onClick={handleLogout}>
                Log out
              </button>
            </>
          ) : (
            <>
              <NavLink to="/login" className="btn btn-ghost">
                Log in
              </NavLink>
              <NavLink to="/register" className="btn btn-primary">
                Sign up
              </NavLink>
            </>
          )}
        </div>
      </div>
    </header>
  );
}
