import DesktopLayout from '../../components/layout/DesktopLayout';
import { useAuth } from '../../contexts/AuthContext';
import {
  instructorUser,
  instructorMenuItems,
} from '../../data/instructor';
import InstructorDashboardView from './InstructorDashboardView';
import TutorDashboardView from './TutorDashboardView';
import './Instructor.css';

export default function InstructorDashboard() {
  const { user } = useAuth();
  const currentUser = user || instructorUser;

  // Determine whether to show Tutor view or Main Instructor view
  const isTutor = currentUser.role === 'tutor';

  return (
    <DesktopLayout
      brandTitle={isTutor ? "EduAI Tutor" : "EduAI Instructor"}
      brandSubtitle={isTutor ? "Mentoring Dashboard" : "AI Co-pilot"}
      menuItems={instructorMenuItems}
      user={currentUser}
      showFooterLinks={true}
      headerTitle={isTutor ? "Mentoring & Support Dashboard" : "AI Integrated Dashboard"}
      headerAction="Create Announcement"
      headerActionIcon="campaign"
    >
      {isTutor ? <TutorDashboardView /> : <InstructorDashboardView />}
    </DesktopLayout>
  );
}
