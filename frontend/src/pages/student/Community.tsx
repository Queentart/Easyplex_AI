/* ==========================================================
 * Community 페이지
 * ----------------------------------------------------------
 * (목업 화면 #13) 커뮤니티 피드 (익명 게시판)
 * ========================================================== */

import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import MobileLayout from '../../components/layout/MobileLayout';
import StatusTag from '../../components/common/StatusTag';
import CommentsModal from '../../components/common/CommentsModal';
import CreatePostModal from './components/CreatePostModal';
import { studentBottomNav, communityPosts as initialPosts, saveCommunityPosts } from '../../data/student';
import type { CommunityPost } from '../../types';
import './Student.css';

export default function Community() {
  const navigate = useNavigate();
  const [posts, setPosts] = useState<CommunityPost[]>(initialPosts);
  const [selectedPost, setSelectedPost] = useState<CommunityPost | null>(null);
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);

  // 전역 mock 데이터(initialPosts)가 변경되었을 수 있으므로 화면 진입 시 동기화
  useEffect(() => {
    setPosts([...initialPosts]);
  }, []);

  const handleLike = (e: React.MouseEvent, postId: string) => {
    e.stopPropagation(); // 카드 클릭(이동) 방지
    setPosts(prev => prev.map(p => {
      if (p.id === postId) {
        const updated = { ...p, isLiked: !p.isLiked, likes: p.isLiked ? p.likes - 1 : p.likes + 1 };
        const index = initialPosts.findIndex(ip => ip.id === postId);
        if (index !== -1) {
          initialPosts[index] = updated;
          saveCommunityPosts();
        }
        return updated;
      }
      return p;
    }));
    // 백엔드 시뮬레이션
    fetch(`http://localhost:8000/api/v1/student/community/${postId}/like`, { method: 'POST' }).catch(console.error);
  };

  const handleReportPost = (e: React.MouseEvent, postId: string) => {
    e.stopPropagation();
    alert(`게시글 신고가 접수되었습니다. (Post ID: ${postId})`);
    fetch('http://localhost:8000/api/v1/student/community/report', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ type: 'post', target_id: postId, reason: 'inappropriate content' })
    }).catch(console.error);
  };

  const handleOpenComments = (e: React.MouseEvent, post: CommunityPost) => {
    e.stopPropagation();
    setSelectedPost(post);
  };

  const handleViewPost = (postId: string) => {
    setSelectedPost(null);
    navigate(`/student/community/${postId}`);
  };

  const handleReportComment = (commentId: string) => {
    alert(`댓글 신고가 접수되었습니다. (Comment ID: ${commentId})`);
    fetch('http://localhost:8000/api/v1/student/community/report', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ type: 'comment', target_id: commentId, reason: 'inappropriate content' })
    }).catch(console.error);
  };

  const handleCreatePost = (content: string, files: File[]) => {
    const newPost: CommunityPost = {
      id: `post_${Date.now()}`,
      author: 'Student User',
      tag: 'freetalk',
      timeAgo: '방금 전',
      content: content,
      likes: 0,
      comments: 0,
      isLiked: false,
      attachments: files.map(f => ({
        name: f.name,
        type: f.type,
        size: f.size,
        url: URL.createObjectURL(f)
      }))
    };
    
    // 모의 데이터(Mock Data) 환경이므로 상세 페이지에서 게시글을 찾을 수 있도록 전역 배열에 추가
    initialPosts.unshift(newPost);
    saveCommunityPosts();
    
    setPosts([newPost, ...posts]);
  };

  return (
    <MobileLayout title="Community" bottomNavItems={studentBottomNav}>
      <div className="pb-4">
        {/* 글쓰기 버튼 블록 */}
        <div className="community-create-block">
          <button 
            className="community-create-btn"
            onClick={() => setIsCreateModalOpen(true)}
          >
            <div className="community-create-avatar">
              <img src="https://api.dicebear.com/7.x/avataaars/svg?seed=이지" alt="Profile" />
            </div>
            <span className="community-create-text">새로운 글을 작성해보세요...</span>
            <span className="material-icons-outlined community-create-icon">image</span>
          </button>
        </div>

        {posts.map(post => (
          <div 
            key={post.id} 
            className="community-post cursor-pointer hover:bg-gray-50 transition"
            onClick={() => handleViewPost(post.id)}
          >
            {/* 헤더: 작성자 + 시간 + 태그 + 신고 */}
            <div className="community-post__header">
              <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-2)' }}>
                <span className="community-post__author">{post.author}</span>
                <StatusTag label={post.tag} variant={post.tag} />
              </div>
              <div className="flex items-center gap-2">
                <span className="community-post__time">{post.timeAgo}</span>
                <button 
                  onClick={(e) => handleReportPost(e, post.id)} 
                  className="text-gray-300 hover:text-red-500 transition"
                  title="Report Post"
                >
                  <span className="material-icons-outlined" style={{ fontSize: 16 }}>report_problem</span>
                </button>
              </div>
            </div>

            {/* 내용 */}
            <div className="community-post__content line-clamp-3">{post.content}</div>

            {/* 피드 파일 미리보기 */}
            {post.attachments && post.attachments.length > 0 && (
              <div className="mt-4 mb-4 flex flex-wrap gap-2">
                {post.attachments.map((file, idx) => (
                  <div key={idx} className="flex items-center gap-1.5 bg-gray-50 border border-gray-200 rounded-md px-2 py-1 text-xs text-gray-600 max-w-[200px]">
                    <span className="material-icons-outlined text-[14px]">
                      {file.type.startsWith('image/') ? 'image' : file.type.startsWith('video/') ? 'movie' : file.type.startsWith('audio/') ? 'audiotrack' : 'insert_drive_file'}
                    </span>
                    <span className="truncate">{file.name}</span>
                  </div>
                ))}
              </div>
            )}

            {/* 푸터: 좋아요 + 댓글 */}
            <div className="community-post__footer">
              <button 
                className={`community-post__action ${post.isLiked ? 'text-red-500' : ''}`}
                onClick={(e) => handleLike(e, post.id)}
              >
                <span className="material-icons-outlined" style={{ fontSize: 16 }}>
                  {post.isLiked ? 'favorite' : 'favorite_border'}
                </span>
                {post.likes}
              </button>
              <button 
                className="community-post__action"
                onClick={(e) => handleOpenComments(e, post)}
              >
                <span className="material-icons-outlined" style={{ fontSize: 16 }}>chat_bubble_outline</span>
                {post.comments}
              </button>
            </div>
          </div>
        ))}
      </div>

      {selectedPost && (
        <CommentsModal 
          post={selectedPost} 
          onClose={() => setSelectedPost(null)}
          onViewPost={handleViewPost}
          onReportComment={handleReportComment}
        />
      )}

      <CreatePostModal 
        isOpen={isCreateModalOpen}
        onClose={() => setIsCreateModalOpen(false)}
        onSubmit={handleCreatePost}
      />
    </MobileLayout>
  );
}
