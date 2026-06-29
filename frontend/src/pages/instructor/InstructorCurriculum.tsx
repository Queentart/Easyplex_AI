import CurriculumMgmt from '../shared/CurriculumMgmt';
import { useAuth } from '../../contexts/AuthContext';
import { instructorUser, instructorMenuItems } from '../../data/instructor';

export default function InstructorCurriculum() {
  const { user } = useAuth();
  const currentUser = user || instructorUser;

  return (
    <CurriculumMgmt 
      brandTitle="EduAI Instructor"
      brandSubtitle="AI Co-pilot"
      menuItems={instructorMenuItems}
      user={currentUser}
      logoutLabel="Logout"
    />
  );
}
