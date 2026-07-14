// Route table for the whole app. Public routes (browse, listing detail, auth)
// sit alongside role-guarded routes wrapped in <ProtectedRoute>.

import { Route, Routes } from "react-router-dom";

import { NavBar } from "./components/NavBar";
import { ProtectedRoute } from "./components/ProtectedRoute";

import { LoginPage } from "./pages/LoginPage";
import { RegisterPage } from "./pages/RegisterPage";
import { BrowsePage } from "./pages/BrowsePage";
import { ListingDetailPage } from "./pages/ListingDetailPage";
import { MessagesPage } from "./pages/MessagesPage";
import { ForbiddenPage } from "./pages/ForbiddenPage";
import { NotFoundPage } from "./pages/NotFoundPage";

import { FavoritesPage } from "./pages/buyer/FavoritesPage";
import { MyInquiriesPage } from "./pages/buyer/MyInquiriesPage";

import { MyListingsPage } from "./pages/seller/MyListingsPage";
import { CreateListingPage } from "./pages/seller/CreateListingPage";
import { EditListingPage } from "./pages/seller/EditListingPage";
import { SellerInquiriesPage } from "./pages/seller/SellerInquiriesPage";

import { DisputeQueuePage } from "./pages/support/DisputeQueuePage";
import { ReportDetailPage } from "./pages/support/ReportDetailPage";

import { AdminUsersPage } from "./pages/admin/AdminUsersPage";
import { AdminListingsPage } from "./pages/admin/AdminListingsPage";
import { AdminAuditPage } from "./pages/admin/AdminAuditPage";

export function App() {
  return (
    <div className="app">
      <NavBar />
      <main className="content">
        <Routes>
          {/* Public */}
          <Route path="/" element={<BrowsePage />} />
          <Route path="/listings/:id" element={<ListingDetailPage />} />
          <Route path="/login" element={<LoginPage />} />
          <Route path="/register" element={<RegisterPage />} />
          <Route path="/forbidden" element={<ForbiddenPage />} />

          {/* Chat — any authenticated user (1:1 for buyer/seller, dispute groups for support) */}
          <Route
            path="/messages"
            element={
              <ProtectedRoute roles={["buyer", "seller", "support", "admin"]}>
                <MessagesPage />
              </ProtectedRoute>
            }
          />

          {/* Buyer */}
          <Route
            path="/favorites"
            element={
              <ProtectedRoute roles={["buyer"]}>
                <FavoritesPage />
              </ProtectedRoute>
            }
          />
          <Route
            path="/inquiries"
            element={
              <ProtectedRoute roles={["buyer"]}>
                <MyInquiriesPage />
              </ProtectedRoute>
            }
          />

          {/* Seller */}
          <Route
            path="/seller/listings"
            element={
              <ProtectedRoute roles={["seller"]}>
                <MyListingsPage />
              </ProtectedRoute>
            }
          />
          <Route
            path="/seller/listings/new"
            element={
              <ProtectedRoute roles={["seller"]}>
                <CreateListingPage />
              </ProtectedRoute>
            }
          />
          <Route
            path="/seller/listings/:id/edit"
            element={
              <ProtectedRoute roles={["seller", "admin"]}>
                <EditListingPage />
              </ProtectedRoute>
            }
          />
          <Route
            path="/seller/inquiries"
            element={
              <ProtectedRoute roles={["seller"]}>
                <SellerInquiriesPage />
              </ProtectedRoute>
            }
          />

          {/* Support + admin */}
          <Route
            path="/support/disputes"
            element={
              <ProtectedRoute roles={["support", "admin"]}>
                <DisputeQueuePage />
              </ProtectedRoute>
            }
          />
          <Route
            path="/support/reports/:id"
            element={
              <ProtectedRoute roles={["support", "admin"]}>
                <ReportDetailPage />
              </ProtectedRoute>
            }
          />

          {/* Admin */}
          <Route
            path="/admin/users"
            element={
              <ProtectedRoute roles={["admin"]}>
                <AdminUsersPage />
              </ProtectedRoute>
            }
          />
          <Route
            path="/admin/listings"
            element={
              <ProtectedRoute roles={["admin"]}>
                <AdminListingsPage />
              </ProtectedRoute>
            }
          />
          <Route
            path="/admin/audit"
            element={
              <ProtectedRoute roles={["admin"]}>
                <AdminAuditPage />
              </ProtectedRoute>
            }
          />

          <Route path="*" element={<NotFoundPage />} />
        </Routes>
      </main>
    </div>
  );
}
