import CurriculumMgmt from '../shared/CurriculumMgmt';
import { useAuth } from '../../contexts/AuthContext';
import { opsUser, opsMenu } from '../../data/eduops';

export default function EduOpsCurriculum() {
  const { user } = useAuth();
  const currentUser = user || opsUser;

  return (
    <CurriculumMgmt 
      brandTitle="EduAI Operations"
      brandSubtitle="Student & Ops"
      menuItems={opsMenu}
      user={currentUser}
      logoutLabel="Logout"
    />
  );
}
