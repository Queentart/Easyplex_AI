import { useState, useRef } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import MobileLayout from '../../components/layout/MobileLayout';
import StatusTag from '../../components/common/StatusTag';
import { studentBottomNav, communityPosts, studentUser, saveCommunityPosts } from '../../data/student';
import type { CommunityPost, CommunityComment } from '../../types';

export default function PostDetail() {
  const { postId } = useParams<{ postId: string }>();
  const navigate = useNavigate();
  const found = communityPosts.find(p => p.id === postId) || null;
  const [post, setPost] = useState<CommunityPost | null>(found);
  const [newComment, setNewComment] = useState('');
  const [isEditing, setIsEditing] = useState(false);
  const [editContent, setEditContent] = useState(found?.content || '');
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  const isAuthor = post?.author === studentUser.name;
  if (!post) {
    return (
      <MobileLayout title="Community" bottomNavItems={studentBottomNav}>
        <div className="p-6 text-center text-gray-500">Post not found.</div>
      </MobileLayout>
    );
  }

  const handleLikePost = () => {
    setPost(prev => {
      if (!prev) return prev;
      const updated = {
        ...prev,
        isLiked: !prev.isLiked,
        likes: prev.isLiked ? prev.likes - 1 : prev.likes + 1
      };
      
      const index = communityPosts.findIndex(p => p.id === updated.id);
      if (index !== -1) {
        communityPosts[index] = updated;
        saveCommunityPosts();
      }
      return updated;
    });
    // [백엔드 API 호출 시뮬레이션]
    fetch(`http://localhost:8000/api/v1/student/community/${post.id}/like`, { method: 'POST' }).catch(console.error);
  };

  const handleEditPost = async () => {
    if (!post) return;
    await fetch(`http://localhost:8000/api/v1/student/community/${post.id}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ content: editContent })
    }).catch(console.error);
    
    setPost(prev => {
      const updated = prev ? { ...prev, content: editContent } : prev;
      if (updated) {
        const index = communityPosts.findIndex(p => p.id === updated.id);
        if (index !== -1) {
          communityPosts[index] = updated;
          saveCommunityPosts();
        }
      }
      return updated;
    });
    setIsEditing(false);
  };

  const handleDeletePost = async () => {
    if (!post) return;
    if (!window.confirm('정말로 이 게시글을 삭제하시겠습니까?')) return;
    
    await fetch(`http://localhost:8000/api/v1/student/community/${post.id}`, {
      method: 'DELETE'
    }).catch(console.error);

    // 모의 데이터 전역 배열에서 삭제 처리
    const index = communityPosts.findIndex(p => p.id === post.id);
    if (index !== -1) {
      communityPosts.splice(index, 1);
      saveCommunityPosts();
    }

    alert('게시글이 삭제되었습니다.');
    navigate('/student/community');
  };

  const handleReportPost = () => {
    alert(`게시글 신고가 접수되었습니다. (Post ID: ${post.id})`);
    fetch('http://localhost:8000/api/v1/student/community/report', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ type: 'post', target_id: post.id, reason: 'inappropriate content' })
    }).catch(console.error);
  };

  const handleReportComment = (commentId: string) => {
    alert(`댓글 신고가 접수되었습니다. (Comment ID: ${commentId})`);
    fetch('http://localhost:8000/api/v1/student/community/report', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ type: 'comment', target_id: commentId, reason: 'inappropriate content' })
    }).catch(console.error);
  };

  const handleLikeComment = (commentId: string) => {
    setPost(prev => {
      if (!prev || !prev.commentsList) return prev;
      const updated = {
        ...prev,
        commentsList: prev.commentsList.map(c => 
          c.id === commentId 
            ? { ...c, isLiked: !c.isLiked, likes: c.isLiked ? c.likes - 1 : c.likes + 1 }
            : c
        )
      };
      const index = communityPosts.findIndex(p => p.id === updated.id);
      if (index !== -1) {
        communityPosts[index] = updated;
        saveCommunityPosts();
      }
      return updated;
    });
    fetch(`http://localhost:8000/api/v1/student/community/comments/${commentId}/like`, { method: 'POST' }).catch(console.error);
  };

  const handleSubmitComment = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newComment.trim()) return;

    const addedComment: CommunityComment = {
      id: `new_${Date.now()}`,
      author: 'Student User', // 현재 로그인된 사용자
      timeAgo: 'Just now',
      content: newComment,
      likes: 0,
      isLiked: false
    };

    setPost(prev => {
      if (!prev) return prev;
      const updated = {
        ...prev,
        commentsList: [...(prev.commentsList || []), addedComment],
        comments: prev.comments + 1
      };
      const index = communityPosts.findIndex(p => p.id === updated.id);
      if (index !== -1) {
        communityPosts[index] = updated;
        saveCommunityPosts();
      }
      return updated;
    });
    setNewComment('');
    if (textareaRef.current) {
      textareaRef.current.style.height = '52px';
    }
    
    // [백엔드 API 호출 시뮬레이션]
    fetch(`http://localhost:8000/api/v1/student/community/${post.id}/comment`, { method: 'POST' }).catch(console.error);
  };

  const handleCommentChange = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    setNewComment(e.target.value);
    // Auto-resize textarea
    e.target.style.height = 'auto';
    const newHeight = Math.min(e.target.scrollHeight, 150); // Max height 150px
    e.target.style.height = `${newHeight}px`;
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSubmitComment(e as unknown as React.FormEvent);
    }
  };

  return (
    <MobileLayout 
      title="Post Detail" 
      bottomNavItems={studentBottomNav}
    >
      <div className="bg-white min-h-full pb-[120px]">
        {/* 전체 너비 꽉 채우는 컨테이너 */}
        <div className="w-full flex flex-col min-h-full relative">
          
          {/* 뒤로가기 영역 */}
          <div 
            className="flex items-center border-b border-gray-100 cursor-pointer text-gray-600 hover:bg-gray-50 transition-colors" 
            onClick={() => navigate(-1)}
            style={{ padding: '16px 24px', display: 'flex', alignItems: 'center' }}
          >
            <span className="material-icons-outlined" style={{ marginRight: '8px' }}>arrow_back</span>
            <span className="font-semibold text-sm">Back to Community</span>
          </div>

          {/* 본문 */}
          <div className="border-b border-gray-100" style={{ padding: '32px 24px' }}>
            <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: '24px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
                <div 
                  className="rounded-full flex items-center justify-center font-bold text-lg"
                  style={{ width: '48px', height: '48px', minWidth: '48px', backgroundColor: '#e0f2fe', color: '#0369a1' }}
                >
                  {post.author[0]}
                </div>
                <div>
                  <div className="text-base font-bold text-gray-900 flex items-center" style={{ gap: '8px' }}>
                    {post.author}
                    {isAuthor && <span className="bg-blue-100 text-blue-700 rounded text-xs font-semibold" style={{ padding: '2px 8px' }}>Me</span>}
                    <StatusTag label={post.tag} variant={post.tag} />
                  </div>
                  <div className="text-sm text-gray-500" style={{ marginTop: '4px' }}>{post.timeAgo}</div>
                </div>
              </div>
              
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                {isAuthor ? (
                  <>
                    <button onClick={() => setIsEditing(!isEditing)} className="text-gray-400 hover:text-blue-500 transition rounded-full hover:bg-blue-50" title="Edit Post" style={{ padding: '10px' }}>
                      <span className="material-icons-outlined" style={{ fontSize: 20 }}>edit</span>
                    </button>
                    <button onClick={handleDeletePost} className="text-gray-400 hover:text-red-500 transition rounded-full hover:bg-red-50" title="Delete Post" style={{ padding: '10px' }}>
                      <span className="material-icons-outlined" style={{ fontSize: 20 }}>delete</span>
                    </button>
                  </>
                ) : (
                  <button onClick={handleReportPost} className="text-gray-400 hover:text-red-500 transition rounded-full hover:bg-red-50" title="Report Post" style={{ padding: '10px' }}>
                    <span className="material-icons-outlined" style={{ fontSize: 20 }}>report_problem</span>
                  </button>
                )}
              </div>
            </div>

            {isEditing ? (
              <div style={{ marginTop: '16px' }}>
                <textarea
                  value={editContent}
                  onChange={e => setEditContent(e.target.value)}
                  className="w-full border border-gray-300 rounded-xl focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent resize-none text-base leading-relaxed"
                  style={{ height: '160px', padding: '16px' }}
                />
                <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '12px', marginTop: '16px' }}>
                  <button onClick={() => setIsEditing(false)} className="text-sm font-semibold text-gray-600 bg-gray-100 rounded-lg hover:bg-gray-200 transition" style={{ padding: '10px 20px' }}>Cancel</button>
                  <button onClick={handleEditPost} className="text-sm font-semibold text-white bg-primary rounded-lg hover:bg-primary-dark transition" style={{ padding: '10px 20px' }}>Save</button>
                </div>
              </div>
            ) : (
              <div style={{ marginTop: '8px' }}>
                <p className="text-lg text-gray-800 leading-relaxed whitespace-pre-wrap break-words">
                  {post.content}
                </p>
                {post.attachments && post.attachments.length > 0 && (
                  <div className="mt-6 flex flex-col gap-3">
                    <h5 className="text-sm font-semibold text-gray-700">첨부파일 ({post.attachments.length}개)</h5>
                    <div className="flex flex-wrap gap-3">
                      {post.attachments.map((file, idx) => (
                        <a key={idx} href={file.url} target="_blank" rel="noreferrer" className="flex items-center gap-3 p-3 rounded-xl border border-gray-200 bg-gray-50 hover:bg-gray-100 transition min-w-[240px] max-w-sm">
                          <div className="w-10 h-10 rounded-lg bg-white flex items-center justify-center shadow-sm text-primary flex-shrink-0">
                            <span className="material-icons-outlined">
                              {file.type.startsWith('image/') ? 'image' : file.type.startsWith('video/') ? 'movie' : file.type.startsWith('audio/') ? 'audiotrack' : 'insert_drive_file'}
                            </span>
                          </div>
                          <div className="flex-1 min-w-0">
                            <div className="text-sm font-semibold text-gray-800 truncate">{file.name}</div>
                            <div className="text-xs text-gray-500">{(file.size / 1024).toFixed(1)} KB</div>
                          </div>
                        </a>
                      ))}
                    </div>
                  </div>
                )}
              </div>
            )}

            <div className="border-t border-gray-100" style={{ display: 'flex', alignItems: 'center', gap: '32px', marginTop: '32px', paddingTop: '24px' }}>
              <button 
                onClick={handleLikePost}
                className={`transition ${post.isLiked ? 'text-red-500' : 'text-gray-500 hover:text-red-500'}`}
                style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '1rem', fontWeight: 600, background: 'none', border: 'none', cursor: 'pointer' }}
              >
                <span className="material-icons-outlined">{post.isLiked ? 'favorite' : 'favorite_border'}</span>
                Like {post.likes > 0 && <span style={{ marginLeft: '4px' }}>({post.likes})</span>}
              </button>
              <div className="text-gray-500" style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '1rem', fontWeight: 600 }}>
                <span className="material-icons-outlined">chat_bubble_outline</span>
                Comments ({post.comments})
              </div>
            </div>
          </div>

          {/* 댓글 목록 */}
          <div className="bg-gray-50 flex-1" style={{ padding: '32px 24px', minHeight: '300px' }}>
            <h4 className="text-base font-bold text-gray-900" style={{ marginBottom: '24px', display: 'flex', alignItems: 'center', gap: '8px' }}>
              Comments 
              <span className="bg-gray-200 text-gray-700 rounded-full text-xs" style={{ padding: '2px 10px' }}>{post.commentsList?.length || 0}</span>
            </h4>
            
            <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }} className="space-y-5">
              {(!post.commentsList || post.commentsList.length === 0) ? (
                <div className="text-center text-gray-400" style={{ padding: '64px 0' }}>
                  <span className="material-icons-outlined text-5xl opacity-50" style={{ marginBottom: '16px' }}>forum</span>
                  <p className="text-base font-medium">No comments yet.</p>
                  <p className="text-sm" style={{ marginTop: '4px' }}>Be the first to share your thoughts!</p>
                </div>
              ) : (
                post.commentsList.map(comment => (
                  <div key={comment.id} className="bg-white rounded-xl shadow-sm border border-gray-100 group w-full" style={{ display: 'flex', gap: '16px', padding: '20px', marginBottom: '20px', boxSizing: 'border-box' }}>
                    <div 
                      className="rounded-full bg-gray-100 text-gray-600 font-bold text-sm flex items-center justify-center flex-shrink-0"
                      style={{ width: '40px', height: '40px', minWidth: '40px' }}
                    >
                      {comment.author[0]}
                    </div>
                    <div className="flex-1 min-w-0" style={{ width: '100%' }}>
                      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                        <span className="text-sm font-bold text-gray-900">{comment.author}</span>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                          <span className="text-xs font-medium text-gray-400">{comment.timeAgo}</span>
                          <button onClick={() => handleReportComment(comment.id)} className="text-gray-400 hover:text-red-500 opacity-0 group-hover:opacity-100 transition" title="Report" style={{ background: 'none', border: 'none', padding: 0, cursor: 'pointer' }}>
                            <span className="material-icons-outlined" style={{ fontSize: 16 }}>report_problem</span>
                          </button>
                        </div>
                      </div>
                      <p className="text-base text-gray-700 leading-relaxed break-words whitespace-pre-wrap" style={{ marginTop: '8px' }}>{comment.content}</p>
                      
                      <button 
                        onClick={() => handleLikeComment(comment.id)}
                        className={`transition ${comment.isLiked ? 'text-red-500' : 'text-gray-500 hover:text-red-500'}`}
                        style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '0.75rem', fontWeight: 600, marginTop: '12px', background: 'none', border: 'none', cursor: 'pointer', padding: 0 }}
                      >
                        <span className="material-icons-outlined" style={{ fontSize: 16 }}>
                          {comment.isLiked ? 'favorite' : 'favorite_border'}
                        </span>
                        {comment.likes > 0 && <span>{comment.likes}</span>}
                      </button>
                    </div>
                  </div>
                ))
              )}
            </div>
          </div>

        </div>

        {/* 댓글 입력창 (하단 고정) */}
        <div className="fixed bottom-[var(--bottom-nav-height,0px)] left-0 right-0 md:left-[240px] bg-white border-t border-gray-200 p-4 z-40 shadow-[0_-4px_10px_rgba(0,0,0,0.03)]">
          <form onSubmit={handleSubmitComment} style={{ width: '100%', position: 'relative', display: 'flex', alignItems: 'flex-end' }}>
            <textarea 
              ref={textareaRef}
              value={newComment}
              onChange={handleCommentChange}
              onKeyDown={handleKeyDown}
              placeholder="Write a comment... (Shift+Enter for new line)" 
              rows={1}
              className="bg-gray-100 border border-transparent focus:bg-white focus:border-primary focus:ring-2 focus:ring-primary/20 transition-all shadow-inner resize-none overflow-y-auto"
              style={{ 
                width: '100%', 
                minHeight: '52px', 
                maxHeight: '150px',
                borderRadius: '1rem',
                padding: '14px 60px 14px 24px', // pr-15 to make room for absolute button
                fontSize: '1rem',
                outline: 'none',
                boxSizing: 'border-box'
              }}
            />
            <button 
              type="submit" 
              disabled={!newComment.trim()}
              title="Post Comment"
              style={{ 
                position: 'absolute',
                right: '8px',
                bottom: '6px',
                zIndex: 10,
                width: '40px',
                height: '40px',
                borderRadius: '50%',
                backgroundColor: newComment.trim() ? '#00BFA5' : '#80DFD2',
                color: 'white',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                border: 'none',
                cursor: newComment.trim() ? 'pointer' : 'not-allowed',
                transition: 'all 0.2s ease'
              }}
            >
              <span className="material-icons-outlined" style={{ fontSize: 20, marginLeft: '2px' }}>send</span>
            </button>
          </form>
        </div>

      </div>
    </MobileLayout>
  );
}
