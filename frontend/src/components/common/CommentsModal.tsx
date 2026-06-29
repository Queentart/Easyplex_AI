import type { CommunityPost } from '../../types';

interface CommentsModalProps {
  post: CommunityPost | null;
  onClose: () => void;
  onViewPost: (postId: string) => void;
  onReportComment: (commentId: string) => void;
}

export default function CommentsModal({ post, onClose, onViewPost, onReportComment }: CommentsModalProps) {
  if (!post) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm transition-opacity" onClick={onClose} style={{ padding: '20px' }}>
      {/* 모달 컨테이너 */}
      <div 
        className="bg-white rounded-xl shadow-2xl flex flex-col overflow-hidden"
        style={{ width: '100%', maxWidth: '600px', maxHeight: '85vh', borderRadius: '12px' }}
        onClick={e => e.stopPropagation()}
      >
        {/* 헤더 */}
        <div className="border-b border-gray-200 bg-gray-50 flex-shrink-0 w-full box-border" style={{ padding: '20px 24px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <h3 className="font-bold text-gray-900 m-0 p-0 leading-none" style={{ fontSize: '1.25rem', display: 'flex', alignItems: 'center', gap: '12px' }}>
            <span>Comments</span>
            <span className="font-bold text-primary leading-none flex items-center justify-center" style={{ fontSize: '0.875rem', padding: '4px 12px', backgroundColor: '#e0f2fe', color: '#0369a1', borderRadius: '9999px' }}>
              {post.commentsList?.length || 0}
            </span>
          </h3>
          <button 
            onClick={onClose} 
            className="hover:bg-gray-200 text-gray-500 transition-colors flex-shrink-0"
            style={{ width: '32px', height: '32px', display: 'flex', alignItems: 'center', justifyContent: 'center', borderRadius: '50%', background: 'transparent', border: 'none', cursor: 'pointer' }}
            aria-label="Close"
          >
            <span className="material-icons-outlined" style={{ fontSize: 24, lineHeight: 1 }}>close</span>
          </button>
        </div>

        {/* 댓글 목록 */}
        <div className="flex-1 overflow-y-auto" style={{ padding: '24px' }}>
          {!post.commentsList || post.commentsList.length === 0 ? (
            <div className="text-center flex flex-col items-center" style={{ padding: '48px 0' }}>
              <span className="material-icons-outlined text-gray-300 text-4xl mb-3">chat_bubble_outline</span>
              <p className="text-gray-500 font-medium">No comments yet.</p>
              <p className="text-sm text-gray-400 mt-1">Be the first to share your thoughts!</p>
            </div>
          ) : (
            post.commentsList.map(comment => (
              <div key={comment.id} className="group" style={{ display: 'flex', gap: '16px', marginBottom: '24px' }}>
                <div className="text-primary flex-shrink-0 flex items-center justify-center font-bold" style={{ width: '40px', height: '40px', backgroundColor: '#e0f2fe', color: '#0369a1', borderRadius: '50%', fontSize: '14px' }}>
                  {comment.author[0]}
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center justify-between" style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '8px' }}>
                    <span className="font-bold text-gray-900 truncate" style={{ fontSize: '14px' }}>{comment.author}</span>
                    <span className="text-gray-400 whitespace-nowrap" style={{ fontSize: '12px' }}>{comment.timeAgo}</span>
                  </div>
                  <p className="text-gray-700 leading-relaxed break-words" style={{ fontSize: '14px', margin: '6px 0 0 0' }}>{comment.content}</p>
                  
                  {/* 댓글 하단 액션 (좋아요 / 신고) */}
                  <div className="flex items-center" style={{ display: 'flex', alignItems: 'center', gap: '16px', marginTop: '10px' }}>
                    <button className={`transition ${comment.isLiked ? 'text-red-500' : 'text-gray-500 hover:text-red-500'}`} style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12px', fontWeight: 500, background: 'transparent', border: 'none', cursor: 'pointer', padding: 0 }}>
                      <span className="material-icons-outlined" style={{ fontSize: 16 }}>
                        {comment.isLiked ? 'favorite' : 'favorite_border'}
                      </span>
                      {comment.likes > 0 && <span>{comment.likes}</span>}
                    </button>
                    <button 
                      onClick={() => onReportComment(comment.id)}
                      className="text-gray-400 hover:text-red-500 transition opacity-0 group-hover:opacity-100"
                      style={{ display: 'flex', alignItems: 'center', gap: '4px', fontSize: '12px', background: 'transparent', border: 'none', cursor: 'pointer', padding: 0 }}
                      title="Report comment"
                    >
                      <span className="material-icons-outlined" style={{ fontSize: 16 }}>report_problem</span>
                      Report
                    </button>
                  </div>
                </div>
              </div>
            ))
          )}
        </div>

        {/* 푸터 */}
        <div className="border-t border-gray-200 bg-gray-50 flex-shrink-0 w-full box-border" style={{ padding: '20px 24px', display: 'flex', justifyContent: 'flex-end' }}>
          <button 
            onClick={() => onViewPost(post.id)}
            className="bg-primary text-white font-bold rounded-lg hover:bg-primary-dark transition shadow-sm flex-shrink-0"
            style={{ display: 'flex', alignItems: 'center', gap: '8px', padding: '12px 24px', fontSize: '14px', border: 'none', cursor: 'pointer' }}
          >
            <span className="material-icons-outlined" style={{ fontSize: 18 }}>article</span>
            Read Full Post
          </button>
        </div>
      </div>
    </div>
  );
}
