package com.cometchat.marketplace.ui.profile

import android.content.Intent
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.appcompat.app.AlertDialog
import androidx.fragment.app.Fragment
import com.cometchat.marketplace.databinding.FragmentProfileBinding
import com.cometchat.marketplace.ui.auth.LoginActivity
import com.cometchat.marketplace.ui.repo

/** Current-user summary and logout. */
class ProfileFragment : Fragment() {

    private var _binding: FragmentProfileBinding? = null
    private val binding get() = _binding!!

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?,
    ): View {
        _binding = FragmentProfileBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        val user = repo.currentUser
        binding.name.text = user?.name ?: "—"
        binding.email.text = user?.email ?: "—"
        binding.roleBadge.text = user?.role?.wire?.uppercase() ?: "—"
        binding.userId.text = user?.id ?: "—"
        binding.avatar.text = user?.name?.firstOrNull()?.uppercase() ?: "?"

        binding.logoutButton.setOnClickListener { confirmLogout() }
    }

    private fun confirmLogout() {
        AlertDialog.Builder(requireContext())
            .setTitle("Log out?")
            .setMessage("You'll need to sign in again to continue.")
            .setPositiveButton("Log out") { _, _ ->
                repo.logout()
                val intent = Intent(requireContext(), LoginActivity::class.java)
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                startActivity(intent)
                requireActivity().finish()
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
