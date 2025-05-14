import MintNFTComponent from '@/components/MintNFT'
import { BASE_ERC721_ADDRESS } from "@/config"
function MintNFT() {
    return (
        <MintNFTComponent nftAddress={BASE_ERC721_ADDRESS} />
    )
}

export default MintNFT