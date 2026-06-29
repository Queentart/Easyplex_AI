import { useState, useCallback, useEffect, useMemo, useRef } from 'react';
import { 
  ReactFlow, 
  Controls, 
  Background, 
  applyNodeChanges, 
  applyEdgeChanges,
  addEdge,
  MarkerType,
  BackgroundVariant,
  ReactFlowProvider,
  useReactFlow
} from '@xyflow/react';
import type { 
  Node,
  Edge,
  NodeChange,
  EdgeChange,
  Connection
} from '@xyflow/react';
import '@xyflow/react/dist/style.css';
import type { CurriculumStep } from '../../api/curriculumApi';
import CurriculumCustomNode from './CurriculumCustomNode';
import CurriculumGroupNode from './CurriculumGroupNode';

interface InstructorCurriculumNodeEditorProps {
  steps: CurriculumStep[];
  onSaveBatch: (updatedSteps: Partial<CurriculumStep>[]) => Promise<void>;
}

function InstructorCurriculumNodeEditorInner({ steps, onSaveBatch }: InstructorCurriculumNodeEditorProps) {
  const [nodes, setNodes] = useState<Node[]>([]);
  const [edges, setEdges] = useState<Edge[]>([]);
  const [editingNodeId, setEditingNodeId] = useState<string | null>(null);
  const [editFormData, setEditFormData] = useState({ title: '', status: 'upcoming' });
  
  const { screenToFlowPosition, fitView, getIntersectingNodes } = useReactFlow();
  const [contextMenu, setContextMenu] = useState<{ top: number, left: number, x: number, y: number } | null>(null);
  const [edgeContextMenu, setEdgeContextMenu] = useState<{ id: string, top: number, left: number } | null>(null);
  const [nodeContextMenu, setNodeContextMenu] = useState<{ id: string, top: number, left: number } | null>(null);
  const successfulConnectionRef = useRef<boolean>(false);
  const pendingConnectionRef = useRef<{ nodeId: string | null, handleType: string | null } | null>(null);

  const DUMMY_NODE_ID = 'dummy-drop-node';

  // 커스텀 노드 타입 등록
  const nodeTypes = useMemo(() => ({ 
    curriculumNode: CurriculumCustomNode,
    curriculumGroupNode: CurriculumGroupNode
  }), []);

  const handleGroupTitleChange = useCallback((id: string, title: string) => {
    setNodes(nds => nds.map(n => n.id === id ? { ...n, data: { ...n.data, title } } : n));
  }, []);

  const handleGroupColorChange = useCallback((id: string, color: string) => {
    setNodes(nds => nds.map(n => n.id === id ? { ...n, data: { ...n.data, color } } : n));
  }, []);

  const handleEditNode = useCallback((id: string, currentData: CurriculumStep) => {
    setEditingNodeId(id);
    setEditFormData({ title: currentData.title, status: currentData.status });
  }, []);

  const handleDeleteNode = useCallback((id: string) => {
    if(confirm('정말 이 노드를 삭제하시겠습니까?')) {
      setEdges((eds) => {
        const incomingEdges = eds.filter((e) => e.target === id);
        const outgoingEdges = eds.filter((e) => e.source === id);
        
        const autoHealedEdges: Edge[] = [];
        incomingEdges.forEach(inc => {
          outgoingEdges.forEach(out => {
            autoHealedEdges.push({
              id: `e-healed-${inc.source}-${out.target}-${Math.random().toString(36).substr(2, 9)}`,
              source: inc.source,
              target: out.target,
              type: 'smoothstep',
              animated: true,
              style: { stroke: '#818CF8', strokeWidth: 2 },
              markerEnd: {
                type: MarkerType.ArrowClosed,
                color: '#818CF8',
              }
            });
          });
        });
        
        return [...eds.filter((e) => e.source !== id && e.target !== id), ...autoHealedEdges];
      });
      setNodes((nds) => nds.filter((n) => n.id !== id));
      setContextMenu(null);
      setEdgeContextMenu(null);
      setNodeContextMenu(null);
    }
  }, [setNodes, setEdges]);

  useEffect(() => {
    // 초기 로드시 steps를 노드로 변환
    // display_order 순으로 정렬하여 일렬로 배치
    const sortedSteps = [...steps].sort((a, b) => (a.display_order ?? 0) - (b.display_order ?? 0));
    
    const initialNodes: Node[] = sortedSteps.map((step, idx) => ({
      id: step.id?.toString() || `temp-${idx}`,
      position: { x: idx * 300 + 50, y: 150 },
      data: { 
        label: `${step.title} (${step.status})`,
        stepData: step,
        onEdit: handleEditNode,
        onDelete: handleDeleteNode,
        onChangeColor: handleGroupColorChange
      },
      type: 'curriculumNode'
    }));

    // 노드들을 순서대로 연결하는 엣지 생성 (ComfyUI 스타일의 SmoothStep)
    const initialEdges: Edge[] = [];
    for (let i = 0; i < initialNodes.length - 1; i++) {
      initialEdges.push({
        id: `e${initialNodes[i].id}-${initialNodes[i+1].id}`,
        source: initialNodes[i].id,
        target: initialNodes[i+1].id,
        type: 'smoothstep',
        animated: true,
        style: { stroke: '#818CF8', strokeWidth: 2 },
        markerEnd: {
          type: MarkerType.ArrowClosed,
          color: '#818CF8',
        },
      });
    }
    setTimeout(() => {
      setNodes(initialNodes);
      setEdges(initialEdges);
    }, 0);
  }, [steps, handleEditNode, handleDeleteNode, handleGroupColorChange]);

  const onNodesChange = useCallback(
    (changes: NodeChange<Node>[]) => setNodes((nds) => applyNodeChanges(changes, nds)),
    []
  );

  const onEdgesChange = useCallback(
    (changes: EdgeChange<Edge>[]) => setEdges((eds) => applyEdgeChanges(changes, eds)),
    []
  );

  const onConnect = useCallback(
    (params: Connection | Edge) => {
      successfulConnectionRef.current = true;
      setEdges((eds) => addEdge({
        ...params, 
        type: 'smoothstep',
        animated: true,
        style: { stroke: '#818CF8', strokeWidth: 2 },
        markerEnd: {
          type: MarkerType.ArrowClosed,
          color: '#818CF8',
        }
      } as Edge, eds));
    },
    []
  );

  const handleAddNode = (position?: { x: number, y: number }) => {
    const newId = `new-${Date.now()}`;
    const newNode: Node = {
      id: newId,
      position: position || { x: 50, y: 50 },
      data: {
        label: '새 커리큘럼 단계 (upcoming)',
        stepData: {
          title: '새 커리큘럼 단계',
          status: 'upcoming',
          display_order: nodes.length + 1
        },
        onEdit: handleEditNode,
        onDelete: handleDeleteNode,
        onChangeColor: handleGroupColorChange
      },
      type: 'curriculumNode'
    };
    setNodes((nds) => [...nds.filter(n => n.id !== DUMMY_NODE_ID), newNode]);
    
    const newEdges: Edge[] = [];
    if (pendingConnectionRef.current && pendingConnectionRef.current.nodeId) {
      const isTarget = pendingConnectionRef.current.handleType === 'target';
      newEdges.push({
        id: `e-${pendingConnectionRef.current.nodeId}-${newId}`,
        source: isTarget ? newId : pendingConnectionRef.current.nodeId,
        target: isTarget ? pendingConnectionRef.current.nodeId : newId,
        type: 'smoothstep',
        animated: true,
        style: { stroke: '#818CF8', strokeWidth: 2 },
        markerEnd: { type: MarkerType.ArrowClosed, color: '#818CF8' }
      });
      pendingConnectionRef.current = null;
    }

    setEdges((eds) => [
      ...eds.filter(e => e.source !== DUMMY_NODE_ID && e.target !== DUMMY_NODE_ID), 
      ...newEdges
    ]);
    
    setContextMenu(null);
    setEdgeContextMenu(null);
    setNodeContextMenu(null);
  };

  const handleAddGroupNode = (position?: { x: number, y: number }) => {
    const newId = `group-${Date.now()}`;
    const newNode: Node = {
      id: newId,
      position: position || { x: 50, y: 50 },
      type: 'curriculumGroupNode',
      data: {
        title: '새 섹션',
        color: 'rgba(129, 140, 248, 0.08)',
        onEditTitle: handleGroupTitleChange,
        onChangeColor: handleGroupColorChange
      },
      style: { width: 400, height: 300, zIndex: -1 }
    };
    setNodes(nds => [...nds, newNode]);
    setContextMenu(null);
  };

  const onNodeDragStop = useCallback((_: React.MouseEvent | MouseEvent | TouchEvent, node: Node) => {
    if (node.type !== 'curriculumNode') return;
    
    const intersections = getIntersectingNodes(node).filter(n => n.type === 'curriculumGroupNode');
    
    if (intersections.length > 0) {
      const groupNode = intersections[0];
      if (node.parentId === groupNode.id) return;
      
      setNodes(nds => nds.map(n => {
        if (n.id === node.id) {
          const extendedNode = node as Node & { positionAbsolute?: { x: number; y: number } };
          const absoluteX = extendedNode.positionAbsolute?.x ?? node.position.x;
          const absoluteY = extendedNode.positionAbsolute?.y ?? node.position.y;
          return {
            ...n,
            parentId: groupNode.id,
            position: {
              x: absoluteX - groupNode.position.x,
              y: absoluteY - groupNode.position.y,
            }
          };
        }
        return n;
      }));
    } else {
      if (node.parentId) {
        setNodes(nds => nds.map(n => {
          if (n.id === node.id) {
            const extendedNode = node as Node & { positionAbsolute?: { x: number; y: number } };
            const absoluteX = extendedNode.positionAbsolute?.x ?? node.position.x;
            const absoluteY = extendedNode.positionAbsolute?.y ?? node.position.y;
            return {
              ...n,
              parentId: undefined,
              position: { x: absoluteX, y: absoluteY }
            };
          }
          return n;
        }));
      }
    }
  }, [getIntersectingNodes, setNodes]);

  const handleClearAll = () => {
    if(confirm('모든 노드와 연결을 삭제하시겠습니까?')) {
      setNodes([]);
      setEdges([]);
    }
    setContextMenu(null);
  };

  const handleFitView = () => {
    fitView({ duration: 800 });
    setContextMenu(null);
  };

  const onConnectStart = useCallback((_: MouseEvent | TouchEvent, params: { nodeId: string | null, handleType: string | null }) => {
    successfulConnectionRef.current = false;
    pendingConnectionRef.current = { nodeId: params.nodeId, handleType: params.handleType };
  }, []);

  const onConnectEnd = useCallback(
    (event: MouseEvent | TouchEvent | React.MouseEvent | React.TouchEvent) => {
      if (!successfulConnectionRef.current && pendingConnectionRef.current) {
        const clientX = 'clientX' in event ? event.clientX : (event.changedTouches ? event.changedTouches[0].clientX : 0);
        const clientY = 'clientY' in event ? event.clientY : (event.changedTouches ? event.changedTouches[0].clientY : 0);

        const position = screenToFlowPosition({ x: clientX, y: clientY });
        
        const dummyNode: Node = {
          id: DUMMY_NODE_ID,
          position,
          data: { label: '' },
          type: 'default',
          style: { opacity: 0, width: 1, height: 1, pointerEvents: 'none' }
        };
        
        const isTarget = pendingConnectionRef.current.handleType === 'target';
        const dummyEdge: Edge = {
          id: `e-dummy-${Date.now()}`,
          source: isTarget ? DUMMY_NODE_ID : pendingConnectionRef.current.nodeId!,
          target: isTarget ? pendingConnectionRef.current.nodeId! : DUMMY_NODE_ID,
          type: 'smoothstep',
          animated: true,
          style: { stroke: '#818CF8', strokeWidth: 2, strokeDasharray: '5 5' },
        };
        
        setNodes(nds => [...nds, dummyNode]);
        setEdges(eds => [...eds, dummyEdge]);

        setTimeout(() => {
          setContextMenu({
            top: clientY,
            left: clientX,
            x: position.x,
            y: position.y
          });
          setEdgeContextMenu(null);
        }, 50);
      } else {
        pendingConnectionRef.current = null;
      }
    },
    [screenToFlowPosition]
  );

  const onPaneContextMenu = useCallback((e: React.MouseEvent) => {
    e.preventDefault();
    const position = screenToFlowPosition({ x: e.clientX, y: e.clientY });
    setContextMenu({
      top: e.clientY,
      left: e.clientX,
      x: position.x,
      y: position.y
    });
    setEdgeContextMenu(null);
    setNodeContextMenu(null);
  }, [screenToFlowPosition]);

  const onPaneClick = useCallback(() => {
    setContextMenu(null);
    setEdgeContextMenu(null);
    setNodeContextMenu(null);
    pendingConnectionRef.current = null;
    setNodes(nds => nds.filter(n => n.id !== DUMMY_NODE_ID));
    setEdges(eds => eds.filter(e => e.source !== DUMMY_NODE_ID && e.target !== DUMMY_NODE_ID));
  }, []);

  const onEdgeContextMenu = useCallback((event: React.MouseEvent, edge: Edge) => {
    event.preventDefault();
    setEdgeContextMenu({
      id: edge.id,
      top: event.clientY,
      left: event.clientX,
    });
    setContextMenu(null);
    setNodeContextMenu(null);
  }, []);

  const onNodeContextMenu = useCallback((event: React.MouseEvent, node: Node) => {
    event.preventDefault();
    setNodeContextMenu({
      id: node.id,
      top: event.clientY,
      left: event.clientX,
    });
    setContextMenu(null);
    setEdgeContextMenu(null);
  }, []);

  const handleDeleteEdge = () => {
    if (edgeContextMenu) {
      setEdges(eds => eds.filter(e => e.id !== edgeContextMenu.id));
      setEdgeContextMenu(null);
    }
  };

  const saveNodeEdit = () => {
    if (!editingNodeId) return;
    setNodes((nds) => 
      nds.map((node) => {
        if (node.id === editingNodeId) {
          const updatedStepData = {
            ...node.data.stepData as CurriculumStep,
            title: editFormData.title,
            status: editFormData.status as CurriculumStep['status']
          };
          return {
            ...node,
            data: {
              ...node.data,
              label: `${updatedStepData.title} (${updatedStepData.status})`,
              stepData: updatedStepData
            }
          };
        }
        return node;
      })
    );
    setEditingNodeId(null);
  };

  const handleSave = async () => {
    // 엣지 연결을 따라 순서를 재계산하는 로직을 추가하거나,
    // 간단히 위치(X 좌표)를 기준으로 순서를 결정
    const sortedNodes = [...nodes].sort((a, b) => a.position.x - b.position.x);
    
    const updatedSteps: Partial<CurriculumStep>[] = sortedNodes.map((node, index) => {
      const stepData = node.data.stepData as CurriculumStep;
      const isNew = String(stepData.id).startsWith('new-') || node.id.startsWith('new-');
      return {
        ...(isNew ? {} : { id: stepData.id }),
        title: stepData.title,
        status: stepData.status,
        display_order: index + 1
      };
    });

    await onSaveBatch(updatedSteps);
  };

  return (
    <div className="flex flex-col h-[calc(100vh-220px)] min-h-[700px] border border-slate-200 rounded-2xl overflow-hidden shadow-xl bg-slate-50">
      <div className="p-4 bg-white border-b border-slate-200 flex justify-between items-center z-10 shadow-sm">
        <div>
          <h2 className="text-lg font-bold text-slate-800 flex items-center gap-2">
            <span className="material-icons-outlined text-indigo-500">account_tree</span>
            커리큘럼 노드 에디터
          </h2>
          <p className="text-xs text-slate-500 mt-1">노드를 드래그하여 순서를 변경하고 포트를 연결하여 흐름을 구성하세요.</p>
        </div>
        <div className="flex gap-2">
          <button 
            onClick={() => handleAddNode()}
            className="flex items-center gap-2 px-4 py-2.5 bg-white hover:bg-slate-50 text-slate-700 rounded-lg text-sm font-semibold transition-all border border-slate-300 shadow-sm"
          >
            <span className="material-icons-outlined text-sm">add</span>
            새 노드 추가
          </button>
          <button 
            onClick={handleSave}
            className="flex items-center gap-2 px-5 py-2.5 bg-indigo-600 hover:bg-indigo-500 text-white rounded-lg text-sm font-semibold transition-all shadow-lg shadow-indigo-500/20"
          >
            <span className="material-icons-outlined text-sm">save</span>
            배치 저장하기
          </button>
        </div>
      </div>
      <div className="flex-1 w-full h-full relative">
        <ReactFlow
          nodes={nodes}
          edges={edges}
          onNodesChange={onNodesChange}
          onEdgesChange={onEdgesChange}
          onNodeDragStop={onNodeDragStop}
          onConnect={onConnect}
          onConnectStart={onConnectStart}
          onConnectEnd={onConnectEnd}
          onPaneContextMenu={onPaneContextMenu}
          onPaneClick={onPaneClick}
          onEdgeContextMenu={onEdgeContextMenu}
          onNodeContextMenu={onNodeContextMenu}
          nodeTypes={nodeTypes}
          fitView
          className="bg-slate-50"
          minZoom={0.2}
          maxZoom={4}
        >
          <Background color="#CBD5E1" variant={BackgroundVariant.Dots} gap={24} size={2} />
          <Controls className="bg-white border-slate-200 fill-slate-600 shadow-sm" />
        </ReactFlow>

        {/* 노드 편집 모달 */}
        {editingNodeId && (
          <div className="absolute top-0 left-0 w-full h-full bg-slate-900/40 z-50 flex items-center justify-center backdrop-blur-sm">
            <div className="bg-white p-6 rounded-xl border border-slate-200 w-[320px] shadow-2xl flex flex-col gap-4">
              <h3 className="text-slate-800 font-bold text-lg">노드 정보 수정</h3>
              <div className="flex flex-col gap-2">
                <label className="text-xs text-slate-500">단계 제목</label>
                <input 
                  type="text" 
                  value={editFormData.title} 
                  onChange={(e) => setEditFormData({ ...editFormData, title: e.target.value })}
                  className="bg-white border border-slate-300 rounded p-2 text-slate-800 text-sm focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500"
                />
              </div>
              <div className="flex flex-col gap-2">
                <label className="text-xs text-slate-500">진행 상태</label>
                <select 
                  value={editFormData.status} 
                  onChange={(e) => setEditFormData({ ...editFormData, status: e.target.value })}
                  className="bg-white border border-slate-300 rounded p-2 text-slate-800 text-sm focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500"
                >
                  <option value="upcoming">Upcoming (예정)</option>
                  <option value="current">Current (진행중)</option>
                  <option value="completed">Completed (완료)</option>
                </select>
              </div>
              <div className="flex justify-end gap-2 mt-4">
                <button 
                  onClick={() => setEditingNodeId(null)}
                  className="px-4 py-2 text-sm text-slate-500 hover:text-slate-800"
                >
                  취소
                </button>
                <button 
                  onClick={saveNodeEdit}
                  className="px-4 py-2 bg-indigo-600 hover:bg-indigo-500 text-white rounded text-sm font-semibold"
                >
                  수정 사항 저장
                </button>
              </div>
            </div>
          </div>
        )}

        {/* 커스텀 우클릭 컨텍스트 메뉴 */}
        {contextMenu && (
          <div 
            className="fixed bg-white border border-slate-200 shadow-2xl rounded-lg py-2 min-w-[160px] z-[100]"
            style={{ top: contextMenu.top, left: contextMenu.left }}
          >
            <button 
              className="w-full text-left px-4 py-2 text-sm text-slate-700 hover:bg-slate-50 flex items-center gap-2"
              onClick={() => handleAddNode({ x: contextMenu.x, y: contextMenu.y })}
            >
              <span className="material-icons-outlined text-[16px] text-indigo-500">add_circle</span>
              새 노드 추가
            </button>
            <button 
              className="w-full text-left px-4 py-2 text-sm text-slate-700 hover:bg-slate-50 flex items-center gap-2"
              onClick={() => handleAddGroupNode({ x: contextMenu.x, y: contextMenu.y })}
            >
              <span className="material-icons-outlined text-[16px] text-amber-500">snippet_folder</span>
              새 그룹 추가
            </button>
            <button 
              className="w-full text-left px-4 py-2 text-sm text-slate-700 hover:bg-slate-50 flex items-center gap-2"
              onClick={handleFitView}
            >
              <span className="material-icons-outlined text-[16px] text-emerald-500">zoom_out_map</span>
              화면 정렬 (Fit View)
            </button>
            <div className="h-[1px] bg-slate-200 my-1"></div>
            <button 
              className="w-full text-left px-4 py-2 text-sm text-slate-700 hover:bg-red-50 flex items-center gap-2 hover:text-red-600"
              onClick={handleClearAll}
            >
              <span className="material-icons-outlined text-[16px] text-red-500">delete_sweep</span>
              모두 지우기
            </button>
          </div>
        )}

        {/* 선(Edge) 우클릭 컨텍스트 메뉴 */}
        {edgeContextMenu && (
          <div 
            className="fixed bg-white border border-slate-200 shadow-2xl rounded-lg py-2 min-w-[120px] z-[100]"
            style={{ top: edgeContextMenu.top, left: edgeContextMenu.left }}
          >
            <button 
              className="w-full text-left px-4 py-2 text-sm text-slate-700 hover:bg-red-50 flex items-center gap-2 hover:text-red-600"
              onClick={handleDeleteEdge}
            >
              <span className="material-icons-outlined text-[16px] text-red-500">link_off</span>
              선 끊기
            </button>
          </div>
        )}

        {/* 노드/그룹 우클릭 컨텍스트 메뉴 */}
        {nodeContextMenu && (
          <div 
            className="fixed bg-white border border-slate-200 shadow-2xl rounded-lg py-2 min-w-[120px] z-[100]"
            style={{ top: nodeContextMenu.top, left: nodeContextMenu.left }}
          >
            <button 
              className="w-full text-left px-4 py-2 text-sm text-slate-700 hover:bg-red-50 flex items-center gap-2 hover:text-red-600"
              onClick={() => handleDeleteNode(nodeContextMenu.id)}
            >
              <span className="material-icons-outlined text-[16px] text-red-500">delete</span>
              삭제하기
            </button>
          </div>
        )}
      </div>
    </div>
  );
}

export default function InstructorCurriculumNodeEditor(props: InstructorCurriculumNodeEditorProps) {
  return (
    <ReactFlowProvider>
      <InstructorCurriculumNodeEditorInner {...props} />
    </ReactFlowProvider>
  );
}

