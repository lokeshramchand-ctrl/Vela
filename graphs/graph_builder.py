import logging
from typing import Any

import networkx as nx

from database.mongo import db

logger = logging.getLogger(__name__)

class KnowledgeGraphBuilder:
    def __init__(self):
        # Directed Graph to represent asymmetric relationships (e.g., Merchant BELONGS_TO Cluster)
        self.graph = nx.DiGraph()

    async def build_graph(self) -> dict[str, Any]:
        """
        Extracts intelligence from MongoDB and constructs a multi-relational Knowledge Graph.
        """
        logger.info("Constructing Financial Knowledge Graph...")
        self.graph.clear()

        # 1. Fetch raw intelligence from MongoDB
        merchants = [doc async for doc in db.merchant_profiles.find()]
        behaviors = [doc async for doc in db.behavior_patterns.find()]
        feedbacks = [doc async for doc in db.feedback.find()]

        # 2. Map Merchant and Memory Nodes
        for m in merchants:
            name = m.get("canonical_name")
            if not name:
                continue

            memory_state = m.get("memory_state", "EPHEMERAL")

            # Add Merchant Node
            self.graph.add_node(name, node_type="Merchant", entity_type=m.get("entity_type"))

            # Add Memory Node & Relationship
            memory_node_id = f"Memory_{memory_state}"
            self.graph.add_node(memory_node_id, node_type="Memory")
            self.graph.add_edge(name, memory_node_id, relation="HAS_MEMORY_STATE")

        # 3. Map Behavior and Cluster Nodes
        for b in behaviors:
            merchant_name = b.get("merchant_name")
            cluster_id = b.get("discovered_cluster", "noise")

            if merchant_name in self.graph:
                # Add Behavior Node & Relationship
                behavior_node_id = f"Behavior_{merchant_name}"
                self.graph.add_node(
                    behavior_node_id,
                    node_type="Behavior",
                    avg_amount=b.get("avg_amount", 0),
                    periodicity=b.get("periodicity_score", 0)
                )
                self.graph.add_edge(merchant_name, behavior_node_id, relation="REPEATED_WITH")

                # Add Cluster Node & Relationship (Phase 8 integration)
                if cluster_id != "noise":
                    self.graph.add_node(cluster_id, node_type="Cluster")
                    self.graph.add_edge(merchant_name, cluster_id, relation="BELONGS_TO")

        # 4. Map Human Feedback Nodes (Phase 10 integration)
        for f in feedbacks:
            tx_id = str(f.get("transaction_id", "unknown"))
            merchant_name = f.get("merchant_name")

            if merchant_name in self.graph:
                feedback_node_id = f"Feedback_{tx_id}"
                self.graph.add_node(
                    feedback_node_id,
                    node_type="Feedback",
                    is_correction=f.get("is_correction")
                )
                self.graph.add_edge(feedback_node_id, merchant_name, relation="FEEDBACK_ON")

        # Calculate Graph Topology Metrics
        metrics = {
            "total_nodes": self.graph.number_of_nodes(),
            "total_edges": self.graph.number_of_edges(),
            "density": round(nx.density(self.graph), 5)
        }

        logger.info(f"Knowledge Graph Generation Complete: {metrics}")
        return metrics

    def get_merchant_neighborhood(self, merchant_name: str, radius: int = 2) -> dict[str, Any]:
        """
        Extracts the ego graph (local neighborhood) for a specific merchant.
        Useful for visualization or extracting context for the Phase 12 RAG LLM.
        """
        if merchant_name not in self.graph:
            return {"error": f"Merchant '{merchant_name}' not found in the Knowledge Graph."}

        # Extract the local subgraph within the specified radius
        ego_graph = nx.ego_graph(self.graph, merchant_name, radius=radius)

        # Serialize the graph into a JSON-friendly format for APIs/Visualizations
        nodes = [{"id": n, **ego_graph.nodes[n]} for n in ego_graph.nodes()]
        edges = [{"source": u, "target": v, "relation": d.get("relation")} for u, v, d in ego_graph.edges(data=True)]

        return {
            "target_merchant": merchant_name,
            "nodes": nodes,
            "edges": edges
        }

graph_engine = KnowledgeGraphBuilder()
